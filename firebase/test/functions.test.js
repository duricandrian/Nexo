'use strict';
// Exercises the callable functions end-to-end through the emulators with the
// same flow the app uses (anonymous sign-in, register, bind challenge).
const { test, before } = require('node:test');
const assert = require('node:assert');
const nacl = require('tweetnacl');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');
const {
  getFirestore, connectFirestoreEmulator, doc, setDoc, getDocs, collection, serverTimestamp,
} = require('firebase/firestore');

const host = '127.0.0.1';
const b64 = (u8) => Buffer.from(u8).toString('base64');
let n = 0;

async function client() {
  const app = initializeApp({ projectId: 'demo-nexo', apiKey: 'fake-api-key', appId: 'x' }, `c${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${host}:9099`, { disableWarnings: true });
  const fns = getFunctions(app, 'europe-west6');
  connectFunctionsEmulator(fns, host, 5001);
  const db = getFirestore(app);
  connectFirestoreEmulator(db, host, 8085);
  await signInAnonymously(auth);
  const call = async (name, data) => (await httpsCallable(fns, name)(data)).data;
  return { app, auth, db, call };
}

async function register(c) {
  const kp = nacl.box.keyPair();
  const { id } = await c.call('register', { pk: b64(kp.publicKey) });
  await c.auth.currentUser.getIdToken(true);
  return { id, kp };
}

async function bind(c, id, secretKey) {
  const ch = await c.call('bindChallenge');
  const nonce = nacl.randomBytes(24);
  const box = nacl.box(Buffer.from(ch.challenge, 'base64'), nonce, Buffer.from(ch.serverPk, 'base64'), secretKey);
  return c.call('bind', { id, n: b64(nonce), box: b64(box) });
}

before(async () => {
  // The rules suite may run first and clear data; nothing to prepare here.
});

test('register creates an 8-character ID and sets the nid claim', async () => {
  const c = await client();
  const { id } = await register(c);
  assert.match(id, /^[A-HJ-NP-Z2-9]{8}$/);
  const tok = await c.auth.currentUser.getIdTokenResult();
  assert.strictEqual(tok.claims.nid, id);
  await deleteApp(c.app);
});

test('register rejects malformed keys and unauthenticated callers', async () => {
  const c = await client();
  await assert.rejects(c.call('register', { pk: b64(new Uint8Array(5)) }), /bad_key/);
  await c.auth.signOut();
  await assert.rejects(c.call('register', { pk: b64(new Uint8Array(32)) }), /sign_in_required|unauthenticated/i);
  await deleteApp(c.app);
});

test('bind moves an identity to a new install only with the secret key', async () => {
  const first = await client();
  const { id, kp } = await register(first);

  const thief = await client();
  await assert.rejects(bind(thief, id, nacl.box.keyPair().secretKey), /auth_failed/);
  assert.strictEqual((await thief.auth.currentUser.getIdTokenResult(true)).claims.nid, undefined);

  const restore = await client();
  assert.deepStrictEqual(await bind(restore, id, kp.secretKey), { ok: true });
  assert.strictEqual((await restore.auth.currentUser.getIdTokenResult(true)).claims.nid, id);
  await assert.rejects(bind(restore, 'ZZZZZZZZ', kp.secretKey), /unknown_id/);
  await Promise.all([first, thief, restore].map((c) => deleteApp(c.app)));
});

test('a challenge cannot be reused', async () => {
  const c = await client();
  const { id, kp } = await register(c);
  const ch = await c.call('bindChallenge');
  const nonce = nacl.randomBytes(24);
  const box = nacl.box(Buffer.from(ch.challenge, 'base64'), nonce, Buffer.from(ch.serverPk, 'base64'), kp.secretKey);
  const args = { id, n: b64(nonce), box: b64(box) };
  await c.call('bind', args);
  await assert.rejects(c.call('bind', args), /no_challenge/);
  await deleteApp(c.app);
});

test('ice returns STUN servers and server time', async () => {
  const c = await client();
  await register(c);
  const r = await c.call('ice');
  assert.ok(r.ice[0].urls.length > 0);
  assert.ok(Math.abs(r.time - Date.now()) < 60000);
  await deleteApp(c.app);
});

test('queued envelope reaches the recipient; deleteIdentity removes queue', async () => {
  const a = await client();
  const b = await client();
  const { id: idA } = await register(a);
  const { id: idB } = await register(b);
  await setDoc(doc(a.db, `queues/${idB}/msgs/m1`), { from: idA, data: 'Y2lwaGVy', kind: 'msg', ts: serverTimestamp() });
  const got = await getDocs(collection(b.db, `queues/${idB}/msgs`));
  assert.deepStrictEqual(got.docs.map((d) => d.get('from')), [idA]);

  await b.call('deleteIdentity');
  await assert.rejects(
    setDoc(doc(a.db, `queues/${idB}/msgs/m2`), { from: idA, data: 'x', kind: 'msg', ts: serverTimestamp() }),
    /permission/i,
  );
  await Promise.all([a, b].map((c) => deleteApp(c.app)));
});
