'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const nacl = require('tweetnacl');
const WebSocket = require('ws');

process.env.PORT = '18080';
process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'arcana-'));
let srv;
before(() => { srv = require('../src/index.js'); });
after(() => { srv.wss.close(); srv.server.close(); });

const b64 = (u) => Buffer.from(u).toString('base64');

function client(mode = 'full') {
  const ws = new WebSocket('ws://127.0.0.1:18080/ws');
  const inbox = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const m = JSON.parse(raw);
    const i = waiters.findIndex((w) => w.pred(m));
    if (i >= 0) waiters.splice(i, 1)[0].resolve(m); else inbox.push(m);
  });
  const next = (pred) => new Promise((resolve) => {
    const i = inbox.findIndex(pred);
    if (i >= 0) return resolve(inbox.splice(i, 1)[0]);
    waiters.push({ pred, resolve });
  });
  return { ws, next, send: (o) => ws.send(JSON.stringify(o)), mode };
}

async function login(keys, id, mode = 'full') {
  const c = client(mode);
  const ch = await c.next((m) => m.t === 'challenge');
  if (!id) {
    c.send({ t: 'register', pk: b64(keys.publicKey) });
    id = (await c.next((m) => m.t === 'registered')).id;
  }
  const n = nacl.randomBytes(24);
  const box = nacl.box(Buffer.from(ch.challenge, 'base64'), n, Buffer.from(ch.serverPk, 'base64'), keys.secretKey);
  c.send({ t: 'auth', id, n: b64(n), box: b64(box), mode });
  const a = await c.next((m) => m.t === 'authed' || m.t === 'error');
  return { c, id, a };
}

test('register, auth, store-and-forward, ack, blobs', async () => {
  const ka = nacl.box.keyPair();
  const kb = nacl.box.keyPair();
  const A = await login(ka);
  assert.equal(A.a.t, 'authed');
  assert.match(A.id, /^[A-Z2-9]{8}$/);
  const B0 = await login(kb);
  const bId = B0.id;
  B0.c.ws.close();

  // wrong key cannot impersonate
  const bad = await login(nacl.box.keyPair(), A.id);
  assert.equal(bad.a.error, 'auth_failed');

  A.c.send({ t: 'lookup', rid: 1, id: bId });
  const lk = await A.c.next((m) => m.t === 'lookup');
  assert.equal(lk.pk, b64(kb.publicKey));

  A.c.send({ t: 'send', rid: 2, to: bId, mid: 'm1', data: 'Y2lwaGVy' });
  await A.c.next((m) => m.t === 'sent');

  // notify-mode connection gets only metadata
  const N = await login(kb, bId, 'notify');
  const note = await N.c.next((m) => m.t === 'notify');
  assert.equal(note.from, A.id);
  assert.equal(note.data, undefined);

  const B = await login(kb, bId);
  const msg = await B.c.next((m) => m.t === 'msg');
  assert.equal(msg.data, 'Y2lwaGVy');
  B.c.send({ t: 'ack', mid: 'm1' });
  await new Promise((r) => setTimeout(r, 100));
  B.c.ws.close();
  const B2 = await login(kb, bId);
  B2.c.send({ t: 'ping', rid: 9 });
  const first = await B2.c.next(() => true);
  assert.equal(first.t, 'pong');

  const up = await fetch('http://127.0.0.1:18080/blob', { method: 'POST', headers: { authorization: `Bearer ${A.a.token}` }, body: Buffer.from('encrypted') });
  const { id } = await up.json();
  const dl = await fetch(`http://127.0.0.1:18080/blob/${id}`, { headers: { authorization: `Bearer ${B2.a.token}` } });
  assert.equal(await dl.text(), 'encrypted');
  const unauth = await fetch(`http://127.0.0.1:18080/blob/${id}`);
  assert.equal(unauth.status, 401);

  for (const x of [A, B2, N, bad]) x.c.ws.close();
});
