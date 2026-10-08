'use strict';
// Nexo relay server: authenticates identities by public key, stores and
// forwards opaque end-to-end encrypted envelopes, hosts encrypted blobs and
// issues short-lived TURN credentials. It never sees plaintext.
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const nacl = require('tweetnacl');
const Database = require('better-sqlite3');

const PORT = parseInt(process.env.PORT || '8080', 10);
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const TURN_SECRET = process.env.TURN_SECRET || '';
const TURN_URLS = (process.env.TURN_URLS || '').split(',').map((s) => s.trim()).filter(Boolean);
const STUN_URLS = (process.env.STUN_URLS || 'stun:stun.l.google.com:19302').split(',').map((s) => s.trim()).filter(Boolean);
const MESSAGE_TTL_DAYS = parseInt(process.env.MESSAGE_TTL_DAYS || '30', 10);
const BLOB_TTL_DAYS = parseInt(process.env.BLOB_TTL_DAYS || '14', 10);
const MAX_BLOB_BYTES = parseInt(process.env.MAX_BLOB_BYTES || String(100 * 1024 * 1024), 10);
const MAX_ENVELOPE_BYTES = 256 * 1024;

fs.mkdirSync(path.join(DATA_DIR, 'blobs'), { recursive: true });

const db = new Database(path.join(DATA_DIR, 'relay.db'));
db.pragma('journal_mode = WAL');
db.exec(`
CREATE TABLE IF NOT EXISTS identities (
  id TEXT PRIMARY KEY,
  pk BLOB NOT NULL,
  created INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS queue (
  mid TEXT NOT NULL,
  recipient TEXT NOT NULL,
  sender TEXT NOT NULL,
  data TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'msg',
  ts INTEGER NOT NULL,
  PRIMARY KEY (recipient, mid)
);
CREATE INDEX IF NOT EXISTS queue_recipient ON queue(recipient, ts);
CREATE TABLE IF NOT EXISTS blobs (
  id TEXT PRIMARY KEY,
  owner TEXT NOT NULL,
  size INTEGER NOT NULL,
  ts INTEGER NOT NULL
);
`);

// Server long-term keypair (used for the authentication challenge).
const keyFile = path.join(DATA_DIR, 'server.key');
let serverKeys;
if (fs.existsSync(keyFile)) {
  serverKeys = nacl.box.keyPair.fromSecretKey(new Uint8Array(fs.readFileSync(keyFile)));
} else {
  serverKeys = nacl.box.keyPair();
  fs.writeFileSync(keyFile, Buffer.from(serverKeys.secretKey), { mode: 0o600 });
}

const stmt = {
  getIdentity: db.prepare('SELECT id, pk FROM identities WHERE id = ?'),
  insertIdentity: db.prepare('INSERT INTO identities (id, pk, created, last_seen) VALUES (?, ?, ?, ?)'),
  touchIdentity: db.prepare('UPDATE identities SET last_seen = ? WHERE id = ?'),
  deleteIdentity: db.prepare('DELETE FROM identities WHERE id = ?'),
  enqueue: db.prepare('INSERT OR IGNORE INTO queue (mid, recipient, sender, data, kind, ts) VALUES (?, ?, ?, ?, ?, ?)'),
  pending: db.prepare('SELECT mid, sender, data, kind, ts FROM queue WHERE recipient = ? ORDER BY ts LIMIT 500'),
  pendingSenders: db.prepare('SELECT sender, kind, COUNT(*) AS n FROM queue WHERE recipient = ? GROUP BY sender, kind'),
  ack: db.prepare('DELETE FROM queue WHERE recipient = ? AND mid = ?'),
  purgeQueueFor: db.prepare('DELETE FROM queue WHERE recipient = ?'),
  expireQueue: db.prepare('DELETE FROM queue WHERE ts < ?'),
  insertBlob: db.prepare('INSERT INTO blobs (id, owner, size, ts) VALUES (?, ?, ?, ?)'),
  getBlob: db.prepare('SELECT id, size FROM blobs WHERE id = ?'),
  expiredBlobs: db.prepare('SELECT id FROM blobs WHERE ts < ?'),
  deleteBlob: db.prepare('DELETE FROM blobs WHERE id = ?'),
};

const ID_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function newIdentityId() {
  for (;;) {
    const bytes = crypto.randomBytes(8);
    let id = '';
    for (const b of bytes) id += ID_ALPHABET[b % ID_ALPHABET.length];
    if (!stmt.getIdentity.get(id)) return id;
  }
}

const b64 = (u8) => Buffer.from(u8).toString('base64');
const unb64 = (s) => new Uint8Array(Buffer.from(String(s || ''), 'base64'));

// id -> { full: Set<ws>, notify: Set<ws> }
const online = new Map();
// session token -> { id, exp }
const sessions = new Map();

function conns(id) {
  let c = online.get(id);
  if (!c) {
    c = { full: new Set(), notify: new Set() };
    online.set(id, c);
  }
  return c;
}

function send(ws, obj) {
  if (ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function turnCredentials(id) {
  const ice = [{ urls: STUN_URLS }];
  if (TURN_SECRET && TURN_URLS.length) {
    const username = `${Math.floor(Date.now() / 1000) + 24 * 3600}:${id}`;
    const credential = crypto.createHmac('sha1', TURN_SECRET).update(username).digest('base64');
    ice.push({ urls: TURN_URLS, username, credential });
  }
  return ice;
}

function deliver(recipient, msg) {
  const c = online.get(recipient);
  if (!c) return false;
  if (c.full.size) {
    for (const ws of c.full) send(ws, { t: 'msg', ...msg });
    return true;
  }
  if (msg.kind !== 'eph') {
    for (const ws of c.notify) send(ws, { t: 'notify', from: msg.from, kind: msg.kind });
  }
  return false;
}

function flushQueue(ws, id) {
  for (const row of stmt.pending.all(id)) {
    send(ws, { t: 'msg', mid: row.mid, from: row.sender, data: row.data, kind: row.kind, ts: row.ts });
  }
}

function notifyPending(ws, id) {
  for (const row of stmt.pendingSenders.all(id)) {
    send(ws, { t: 'notify', from: row.sender, kind: row.kind, n: row.n });
  }
}

function checkRate(ws) {
  const now = Date.now();
  if (now - ws.rateWindow > 10000) {
    ws.rateWindow = now;
    ws.rateCount = 0;
  }
  ws.rateCount += 1;
  return ws.rateCount <= 600;
}

function handle(ws, m) {
  switch (m.t) {
    case 'register': {
      const pk = unb64(m.pk);
      if (pk.length !== 32) return send(ws, { t: 'error', rid: m.rid, error: 'bad_pk' });
      const id = newIdentityId();
      const now = Date.now();
      stmt.insertIdentity.run(id, Buffer.from(pk), now, now);
      return send(ws, { t: 'registered', rid: m.rid, id });
    }
    case 'auth': {
      const row = stmt.getIdentity.get(String(m.id || ''));
      if (!row) return send(ws, { t: 'error', rid: m.rid, error: 'unknown_id' });
      const opened = nacl.box.open(unb64(m.box), unb64(m.n), new Uint8Array(row.pk), serverKeys.secretKey);
      if (!opened || !crypto.timingSafeEqual(Buffer.from(opened), Buffer.from(ws.challenge))) {
        return send(ws, { t: 'error', rid: m.rid, error: 'auth_failed' });
      }
      ws.identity = row.id;
      ws.mode = m.mode === 'notify' ? 'notify' : 'full';
      conns(row.id)[ws.mode].add(ws);
      stmt.touchIdentity.run(Date.now(), row.id);
      const token = crypto.randomBytes(24).toString('base64url');
      sessions.set(token, { id: row.id, exp: Date.now() + 24 * 3600 * 1000 });
      ws.token = token;
      send(ws, { t: 'authed', rid: m.rid, id: row.id, token, ice: turnCredentials(row.id), time: Date.now() });
      if (ws.mode === 'full') flushQueue(ws, row.id);
      else notifyPending(ws, row.id);
      return;
    }
    default:
      break;
  }

  if (!ws.identity) return send(ws, { t: 'error', rid: m.rid, error: 'not_authenticated' });
  const me = ws.identity;

  switch (m.t) {
    case 'ping':
      return send(ws, { t: 'pong', rid: m.rid });
    case 'lookup': {
      const row = stmt.getIdentity.get(String(m.id || '').toUpperCase());
      return send(ws, { t: 'lookup', rid: m.rid, id: m.id, pk: row ? b64(row.pk) : null });
    }
    case 'send': {
      if (ws.mode !== 'full') return;
      const to = String(m.to || '');
      const data = String(m.data || '');
      const mid = String(m.mid || '').slice(0, 64);
      const kind = ['msg', 'call', 'eph'].includes(m.kind) ? m.kind : 'msg';
      if (!mid || data.length > MAX_ENVELOPE_BYTES) return send(ws, { t: 'error', rid: m.rid, error: 'bad_message' });
      if (!stmt.getIdentity.get(to)) return send(ws, { t: 'error', rid: m.rid, error: 'unknown_recipient', mid });
      const ts = Date.now();
      const msg = { mid, from: me, data, kind, ts };
      if (kind === 'eph') {
        deliver(to, msg);
      } else {
        stmt.enqueue.run(mid, to, me, data, kind, ts);
        deliver(to, msg);
      }
      return send(ws, { t: 'sent', rid: m.rid, mid, to, ts });
    }
    case 'ack': {
      const mids = Array.isArray(m.mids) ? m.mids : [m.mid];
      for (const mid of mids) stmt.ack.run(me, String(mid));
      return;
    }
    case 'ice':
      return send(ws, { t: 'ice', rid: m.rid, ice: turnCredentials(me) });
    case 'delete_identity': {
      stmt.purgeQueueFor.run(me);
      stmt.deleteIdentity.run(me);
      send(ws, { t: 'deleted', rid: m.rid });
      return ws.close();
    }
    default:
      return send(ws, { t: 'error', rid: m.rid, error: 'unknown_type' });
  }
}

function authFromRequest(req) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  const s = sessions.get(token);
  if (!s || s.exp < Date.now()) return null;
  return s.id;
}

const BLOB_ID_RE = /^[A-Za-z0-9_-]{32}$/;
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (req.method === 'GET' && url.pathname === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ ok: true, pk: b64(serverKeys.publicKey) }));
  }
  if (url.pathname === '/blob' && req.method === 'POST') {
    const owner = authFromRequest(req);
    if (!owner) { res.writeHead(401); return res.end(); }
    const id = crypto.randomBytes(24).toString('base64url');
    const file = path.join(DATA_DIR, 'blobs', id);
    const out = fs.createWriteStream(file);
    let size = 0;
    let aborted = false;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BLOB_BYTES && !aborted) {
        aborted = true;
        out.destroy();
        fs.rm(file, { force: true }, () => {});
        res.writeHead(413);
        res.end();
        req.destroy();
      }
    });
    req.pipe(out);
    out.on('finish', () => {
      if (aborted) return;
      stmt.insertBlob.run(id, owner, size, Date.now());
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ id, size }));
    });
    return;
  }
  const m = url.pathname.match(/^\/blob\/([^/]+)$/);
  if (m && req.method === 'GET') {
    if (!authFromRequest(req)) { res.writeHead(401); return res.end(); }
    if (!BLOB_ID_RE.test(m[1]) || !stmt.getBlob.get(m[1])) { res.writeHead(404); return res.end(); }
    const file = path.join(DATA_DIR, 'blobs', m[1]);
    res.writeHead(200, { 'content-type': 'application/octet-stream', 'content-length': fs.statSync(file).size });
    return fs.createReadStream(file).pipe(res);
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: MAX_ENVELOPE_BYTES * 2 });
wss.on('connection', (ws) => {
  ws.challenge = crypto.randomBytes(32);
  ws.isAlive = true;
  ws.rateWindow = Date.now();
  ws.rateCount = 0;
  ws.on('pong', () => { ws.isAlive = true; });
  send(ws, { t: 'challenge', challenge: b64(ws.challenge), serverPk: b64(serverKeys.publicKey) });
  ws.on('message', (raw) => {
    if (!checkRate(ws)) return send(ws, { t: 'error', error: 'rate_limited' });
    let m;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    try { handle(ws, m); } catch (e) {
      console.error('handler error', e);
      send(ws, { t: 'error', rid: m && m.rid, error: 'internal' });
    }
  });
  ws.on('close', () => {
    if (ws.identity) {
      const c = online.get(ws.identity);
      if (c) {
        c[ws.mode].delete(ws);
        if (!c.full.size && !c.notify.size) online.delete(ws.identity);
      }
    }
    if (ws.token) sessions.delete(ws.token);
  });
});

const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

const janitor = setInterval(() => {
  const now = Date.now();
  stmt.expireQueue.run(now - MESSAGE_TTL_DAYS * 86400000);
  for (const row of stmt.expiredBlobs.all(now - BLOB_TTL_DAYS * 86400000)) {
    fs.rm(path.join(DATA_DIR, 'blobs', row.id), { force: true }, () => {});
    stmt.deleteBlob.run(row.id);
  }
  for (const [t, s] of sessions) if (s.exp < now) sessions.delete(t);
}, 3600000);

wss.on('close', () => { clearInterval(heartbeat); clearInterval(janitor); });

server.listen(PORT, () => console.log(`Nexo relay listening on :${PORT}`));

module.exports = { server, wss };
