import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, getDocs, collection } from 'firebase/firestore';

let env;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run through firebase emulators:exec.');
  env = await initializeTestEnvironment({ projectId: 'demo-agri-rules', firestore: {
    rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'farms/f1'), { name: 'Farm', ownerId: 'owner' });
    for (const [uid, role] of [['owner', 'owner'], ['manager', 'manager'], ['member', 'member']]) {
      await setDoc(doc(db, `farms/f1/members/${uid}`), { uid, role });
      await setDoc(doc(db, `users/${uid}/farms/f1`), { farmId: 'f1', role });
    }
  });
});
const dbFor = (uid, verified = true) => env.authenticatedContext(uid, { email_verified: verified }).firestore();

test('anonymous, unverified and outsider cannot read farm', async () => {
  for (const db of [env.unauthenticatedContext().firestore(), dbFor('owner', false), dbFor('outsider')]) {
    await assertFails(getDoc(doc(db, 'farms/f1')));
  }
});
test('verified member reads farm and own membership but not roster', async () => {
  const db = dbFor('member');
  await assertSucceeds(getDoc(doc(db, 'farms/f1')));
  await assertSucceeds(getDoc(doc(db, 'farms/f1/members/member')));
  await assertFails(getDocs(collection(db, 'farms/f1/members')));
  await assertFails(getDoc(doc(db, 'farms/f1/members/owner')));
});
test('owner and manager can list roster', async () => {
  for (const uid of ['owner', 'manager']) {
    await assertSucceeds(getDocs(collection(dbFor(uid), 'farms/f1/members')));
  }
});
test('no client can self-promote, edit owner, create farm or membership mirror', async () => {
  for (const uid of ['owner', 'manager', 'member', 'outsider']) {
    const db = dbFor(uid);
    await assertFails(setDoc(doc(db, `farms/f1/members/${uid}`), { uid, role: 'owner' }));
    await assertFails(setDoc(doc(db, 'farms/f1'), { name: 'Hijacked', ownerId: uid }));
    await assertFails(setDoc(doc(db, 'farms/new'), { name: 'New', ownerId: uid }));
    await assertFails(setDoc(doc(db, `users/${uid}/farms/f1`), { role: 'owner' }));
  }
});
test('discovery is user-scoped and global farm lists are denied', async () => {
  const db = dbFor('member');
  await assertSucceeds(getDocs(collection(db, 'users/member/farms')));
  await assertFails(getDocs(collection(db, 'users/owner/farms')));
  await assertFails(getDocs(collection(db, 'farms')));
});
test('membership deletion revokes subsequent server reads', async () => {
  const db = dbFor('member');
  await assertSucceeds(getDoc(doc(db, 'farms/f1')));
  await env.withSecurityRulesDisabled(context => deleteDoc(doc(context.firestore(), 'farms/f1/members/member')));
  await assertFails(getDoc(doc(db, 'farms/f1')));
});
