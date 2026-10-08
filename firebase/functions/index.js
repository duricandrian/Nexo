'use strict';
// Nexo backend on Firebase. The functions never see plaintext: messages and
// blobs are end-to-end encrypted on the device. They only bind device-generated
// identities to anonymous Firebase accounts, send content-free push wake-ups and
// expire old data.
const crypto = require('crypto');
const nacl = require('tweetnacl');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');

admin.initializeApp();
const db = admin.firestore();
setGlobalOptions({ region: process.env.NEXO_REGION || 'europe-west6', maxInstances: 10 });

const ID_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MESSAGE_TTL_DAYS = 30;
const BLOB_TTL_DAYS = 14;
const b64 = (u8) => Buffer.from(u8).toString('base64');
const unb64 = (s) => new Uint8Array(Buffer.from(String(s || ''), 'base64'));

function newId() {
  let id = '';
  for (const b of crypto.randomBytes(8)) id += ID_ALPHABET[b % ID_ALPHABET.length];
  return id;
}

function requireAuth(req) {
  if (!req.auth) throw new HttpsError('unauthenticated', 'sign_in_required');
  return req.auth.uid;
}

let serverKeysCache;
async function serverKeys() {
  if (serverKeysCache) return serverKeysCache;
  const ref = db.doc('config/server');
  serverKeysCache = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return { publicKey: unb64(snap.get('pk')), secretKey: unb64(snap.get('sk')) };
    const kp = nacl.box.keyPair();
    tx.set(ref, { pk: b64(kp.publicKey), sk: b64(kp.secretKey) });
    return kp;
  });
  return serverKeysCache;
}

async function setClaim(uid, id) {
  await admin.auth().setCustomUserClaims(uid, { nid: id });
}

/** Creates a new identity for a device-generated public key. */
exports.register = onCall(async (req) => {
  const uid = requireAuth(req);
  const pk = unb64(req.data && req.data.pk);
  if (pk.length !== 32) throw new HttpsError('invalid-argument', 'bad_key');
  for (let i = 0; i < 10; i++) {
    const id = newId();
    const ref = db.doc(`ids/${id}`);
    const created = await db.runTransaction(async (tx) => {
      if ((await tx.get(ref)).exists) return false;
      tx.set(ref, { pk: b64(pk), uid, ts: FieldValue.serverTimestamp() });
      return true;
    });
    if (created) {
      await setClaim(uid, id);
      return { id };
    }
  }
  throw new HttpsError('resource-exhausted', 'no_id');
});

/** Step 1 of re-binding an existing identity (restore/new install). */
exports.bindChallenge = onCall(async (req) => {
  const uid = requireAuth(req);
  const challenge = crypto.randomBytes(32);
  await db.doc(`challenges/${uid}`).set({ c: b64(challenge), ts: Date.now() });
  const keys = await serverKeys();
  return { challenge: b64(challenge), serverPk: b64(keys.publicKey) };
});

/** Step 2: proves possession of the identity's secret key, then binds it. */
exports.bind = onCall(async (req) => {
  const uid = requireAuth(req);
  const { id, n, box } = req.data || {};
  if (typeof id !== 'string' || !/^[A-Z0-9]{8}$/.test(id)) throw new HttpsError('invalid-argument', 'bad_id');
  const chRef = db.doc(`challenges/${uid}`);
  const [ch, row] = await Promise.all([chRef.get(), db.doc(`ids/${id}`).get()]);
  if (!row.exists) throw new HttpsError('not-found', 'unknown_id');
  if (!ch.exists || Date.now() - ch.get('ts') > 120000) throw new HttpsError('failed-precondition', 'no_challenge');
  await chRef.delete();
  const keys = await serverKeys();
  const opened = nacl.box.open(unb64(box), unb64(n), unb64(row.get('pk')), keys.secretKey);
  if (!opened || Buffer.compare(Buffer.from(opened), Buffer.from(ch.get('c'), 'base64')) !== 0) {
    throw new HttpsError('permission-denied', 'auth_failed');
  }
  const previous = row.get('uid');
  await row.ref.update({ uid });
  await setClaim(uid, id);
  if (previous && previous !== uid) {
    await admin.auth().setCustomUserClaims(previous, null).catch(() => {});
    await admin.auth().revokeRefreshTokens(previous).catch(() => {});
  }
  return { ok: true };
});

/** STUN/TURN servers for calls. TURN uses the coturn REST-API scheme. */
exports.ice = onCall(async (req) => {
  requireAuth(req);
  const ice = [{ urls: (process.env.STUN_URLS || 'stun:stun.l.google.com:19302').split(',') }];
  const turnUrls = process.env.TURN_URLS;
  if (turnUrls && process.env.TURN_SECRET) {
    const username = `${Math.floor(Date.now() / 1000) + 24 * 3600}:${req.auth.token.nid || req.auth.uid}`;
    const credential = crypto.createHmac('sha1', process.env.TURN_SECRET).update(username).digest('base64');
    ice.push({ urls: turnUrls.split(','), username, credential });
  } else if (turnUrls && process.env.TURN_USERNAME) {
    ice.push({ urls: turnUrls.split(','), username: process.env.TURN_USERNAME, credential: process.env.TURN_CREDENTIAL || '' });
  }
  return { ice, time: Date.now() };
});

/** Deletes the caller's identity, queue and account. */
exports.deleteIdentity = onCall(async (req) => {
  const uid = requireAuth(req);
  const id = req.auth.token.nid;
  if (id) {
    const row = await db.doc(`ids/${id}`).get();
    if (row.exists && row.get('uid') === uid) {
      await db.recursiveDelete(db.doc(`queues/${id}`));
      await db.doc(`private/${id}`).delete();
      await row.ref.delete();
    }
  }
  await admin.auth().deleteUser(uid).catch(() => {});
  return { ok: true };
});

/** Content-free push wake-up for new envelopes. */
exports.notify = onDocumentCreated('queues/{to}/msgs/{mid}', async (event) => {
  const data = event.data && event.data.data();
  if (!data || data.kind === 'eph') return;
  const priv = await db.doc(`private/${event.params.to}`).get();
  const tokens = (priv.exists && priv.get('fcm')) || [];
  if (!tokens.length) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    data: { t: 'notify', from: String(data.from), kind: String(data.kind) },
    android: { priority: 'high', ttl: data.kind === 'call' ? 60000 : 4 * 7 * 24 * 3600 * 1000 },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-argument') dead.push(tokens[i]);
  });
  if (dead.length) await priv.ref.update({ fcm: FieldValue.arrayRemove(...dead) });
});

/** Expires undelivered envelopes and old blobs. */
exports.cleanup = onSchedule('every 24 hours', async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - MESSAGE_TTL_DAYS * 86400000);
  for (;;) {
    const old = await db.collectionGroup('msgs').where('ts', '<', cutoff).limit(400).get();
    if (old.empty) break;
    const batch = db.batch();
    old.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  const blobCutoff = Date.now() - BLOB_TTL_DAYS * 86400000;
  const [files] = await admin.storage().bucket().getFiles({ prefix: 'blobs/' });
  for (const f of files) {
    if (new Date(f.metadata.timeCreated).getTime() < blobCutoff) await f.delete().catch(() => {});
  }
});
