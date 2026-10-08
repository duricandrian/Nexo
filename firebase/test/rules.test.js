'use strict';
const { test, before, after, beforeEach } = require('node:test');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');

const A = 'AAAAAAAA';
const B = 'BBBBBBBB';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nexo',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8') },
    storage: { rules: fs.readFileSync(path.join(__dirname, '../storage.rules'), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`ids/${A}`).set({ pk: 'a', uid: 'ua' });
    await db.doc(`ids/${B}`).set({ pk: 'b', uid: 'ub' });
    await db.doc(`queues/${B}/msgs/m0`).set({ from: A, data: 'x', kind: 'msg', ts: new Date() });
    await db.doc(`private/${B}`).set({ fcm: ['t'] });
  });
});

const user = (id) => env.authenticatedContext(`u-${id}`, { nid: id }).firestore();
const anon = () => env.authenticatedContext('no-identity').firestore();
const ts = () => require('firebase/compat/app').default.firestore.FieldValue.serverTimestamp();
const env0 = (from, extra = {}) => ({ from, data: 'Y2lwaGVy', kind: 'msg', ts: ts(), ...extra });

test('registered users can look up a public key but not list identities', async () => {
  await assertSucceeds(user(A).doc(`ids/${B}`).get());
  await assertFails(user(A).collection('ids').get());
  await assertFails(anon().doc(`ids/${B}`).get());
  await assertFails(env.unauthenticatedContext().firestore().doc(`ids/${B}`).get());
  await assertFails(user(A).doc(`ids/${A}`).set({ pk: 'evil', uid: 'x' }));
});

test('only the recipient can read and delete its queue', async () => {
  await assertSucceeds(user(B).collection(`queues/${B}/msgs`).get());
  await assertSucceeds(user(B).doc(`queues/${B}/msgs/m0`).delete());
  await assertFails(user(A).collection(`queues/${B}/msgs`).get());
  await assertFails(user(A).doc(`queues/${B}/msgs/m0`).get());
  await assertFails(user(A).doc(`queues/${B}/msgs/m0`).delete());
  await assertFails(anon().collection(`queues/${B}/msgs`).get());
});

test('senders can queue envelopes only under their own identity', async () => {
  await assertSucceeds(user(A).doc(`queues/${B}/msgs/m1`).set(env0(A)));
  await assertSucceeds(user(A).doc(`queues/${B}/msgs/m2`).set(env0(A, { kind: 'call' })));
  await assertFails(user(A).doc(`queues/${B}/msgs/m3`).set(env0(B)));
  await assertFails(anon().doc(`queues/${B}/msgs/m4`).set(env0(A)));
  await assertFails(user(A).doc(`queues/ZZZZZZZZ/msgs/m5`).set(env0(A)));
  await assertFails(user(A).doc(`queues/${B}/msgs/m6`).set(env0(A, { kind: 'admin' })));
  await assertFails(user(A).doc(`queues/${B}/msgs/m7`).set(env0(A, { plain: 'hello' })));
  await assertFails(user(A).doc(`queues/${B}/msgs/m8`).set(env0(A, { ts: new Date(0) })));
  await assertFails(user(A).doc(`queues/${B}/msgs/m9`).set(env0(A, { data: 'x'.repeat(700001) })));
});

test('a sender cannot overwrite someone else\'s envelope', async () => {
  await assertSucceeds(user(A).doc(`queues/${B}/msgs/m0`).set(env0(A)));
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc(`queues/${A}/msgs/fromB`).set({ from: B, data: 'x', kind: 'msg', ts: new Date() }));
  await assertFails(user('CCCCCCCC').doc(`queues/${A}/msgs/fromB`).set(env0('CCCCCCCC')));
});

test('private data (push tokens) is owner-only', async () => {
  await assertSucceeds(user(B).doc(`private/${B}`).get());
  await assertSucceeds(user(A).doc(`private/${A}`).set({ fcm: ['tok'] }));
  await assertFails(user(A).doc(`private/${B}`).get());
  await assertFails(user(A).doc(`private/${B}`).set({ fcm: ['hijack'] }));
});

test('server config, challenges and unknown collections are closed', async () => {
  await assertFails(user(A).doc('config/server').get());
  await assertFails(user(A).doc('challenges/u-AAAAAAAA').get());
  await assertFails(user(A).doc('anything/else').set({ a: 1 }));
});

test('encrypted blobs: registered users may upload and fetch, nobody may list or overwrite', async () => {
  const st = (ctx) => ctx.storage();
  const a = env.authenticatedContext('u-A', { nid: A });
  const id = 'abcdefghijklmnopqrstuvwx';
  const bytes = new Uint8Array([1, 2, 3]);
  await assertSucceeds(st(a).ref(`blobs/${id}`).put(bytes).then());
  await assertSucceeds(st(env.authenticatedContext('u-B', { nid: B })).ref(`blobs/${id}`).getMetadata());
  await assertFails(st(a).ref(`blobs/${id}`).put(bytes).then());
  await assertFails(st(a).ref(`blobs/${id}`).delete());
  await assertFails(st(a).ref('blobs').listAll());
  await assertFails(st(a).ref('blobs/bad.name').put(bytes).then());
  await assertFails(st(a).ref('other/abcdefghijklmnopqrstuvwx').put(bytes).then());
  await assertFails(st(env.authenticatedContext('no-identity')).ref(`blobs/${id}`).getMetadata());
  await assertFails(st(env.unauthenticatedContext()).ref(`blobs/${id}`).getMetadata());
});
