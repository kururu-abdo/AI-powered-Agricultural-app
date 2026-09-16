import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection,
  writeBatch, runTransaction, serverTimestamp, Timestamp } from 'firebase/firestore';
let env;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required.');
  env = await initializeTestEnvironment({ projectId: 'demo-agri-rules', firestore: {
    rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'farms/f1'), { name: 'Farm', ownerId: 'owner', createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    for (const [uid, role] of [['owner', 'owner'], ['manager', 'manager'], ['member', 'member']]) {
      await setDoc(doc(db, `farms/f1/members/${uid}`), { uid, role, updatedAt: Timestamp.now() });
      await setDoc(doc(db, `users/${uid}/farms/f1`), { farmId: 'f1', role });
    }
  });
});
const dbFor = (uid, verified = true) => env.authenticatedContext(uid, { email_verified: verified }).firestore();
async function createFarm(db, uid, id = 'newFarm') {
  try {
  await runTransaction(db, async tx => {
    const farm = doc(db, `farms/${id}`);
    const existing = await tx.get(farm);
    if (existing.exists()) { assert.equal(existing.data().ownerId, uid); return; }
    tx.set(farm, { name: 'New farm', ownerId: uid, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    tx.set(doc(db, `farms/${id}/members/${uid}`), { uid, role: 'owner', updatedAt: serverTimestamp() });
    tx.set(doc(db, `users/${uid}/farms/${id}`), { farmId: id, role: 'owner' });
  });
  } catch (error) {
    if (!['permission-denied', 'aborted'].includes(error.code)) throw error;
    const committed = await getDoc(doc(db, `farms/${id}`));
    if (committed.data()?.ownerId !== uid) throw error;
  }
}
async function assign(db, uid, role, farmId = 'f1') {
  await runTransaction(db, async tx => {
    await tx.get(doc(db, `farms/${farmId}`));
    tx.set(doc(db, `farms/${farmId}/members/${uid}`), { uid, role, updatedAt: serverTimestamp() });
    tx.set(doc(db, `users/${uid}/farms/${farmId}`), { farmId, role });
  });
}
async function remove(db, uid) {
  await runTransaction(db, async tx => {
    await tx.get(doc(db, 'farms/f1'));
    tx.delete(doc(db, `farms/f1/members/${uid}`));
    tx.delete(doc(db, `users/${uid}/farms/f1`));
  });
}
test('verified client atomically bootstraps farm, owner and mirror; retry is safe', async () => {
  const db = dbFor('newOwner');
  await assertSucceeds(createFarm(db, 'newOwner'));
  await assertSucceeds(createFarm(db, 'newOwner'));
  assert.equal((await getDoc(doc(db, 'farms/newFarm/members/newOwner'))).data().role, 'owner');
  assert.equal((await getDoc(doc(db, 'users/newOwner/farms/newFarm'))).data().role, 'owner');
});
test('concurrent client create transactions commit one farm', async () => {
  const db = dbFor('newOwner');
  await assertSucceeds(Promise.all([createFarm(db, 'newOwner'), createFarm(db, 'newOwner')]));
  assert.equal((await getDocs(collection(db, 'users/newOwner/farms'))).size, 1);
});
test('partial bootstrap and forged owner rejected atomically', async () => {
  const db = dbFor('newOwner');
  await assertFails(setDoc(doc(db, 'farms/partial'), {
    name: 'Partial', ownerId: 'newOwner', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(createFarm(db, 'someoneElse', 'forged'));
  assert.equal((await getDoc(doc(db, 'farms/partial'))).exists(), false);
});
test('anonymous and unverified cannot create or read farms', async () => {
  for (const db of [env.unauthenticatedContext().firestore(), dbFor('owner', false)]) {
    await assertFails(getDoc(doc(db, 'farms/f1')));
    await assertFails(createFarm(db, 'owner'));
  }
});
test('outsider cannot read or change another farm', async () => {
  const db = dbFor('outsider');
  await assertFails(getDoc(doc(db, 'farms/f1')));
  await assertFails(assign(db, 'outsider', 'manager'));
});
test('owner can add, promote and demote with matching mirror', async () => {
  const db = dbFor('owner');
  await assertSucceeds(assign(db, 'newMember', 'member'));
  await assertSucceeds(assign(db, 'newMember', 'manager'));
  await assertSucceeds(assign(db, 'newMember', 'member'));
  assert.equal((await getDoc(doc(dbFor('newMember'), 'users/newMember/farms/f1'))).data().role, 'member');
});
test('manager and member cannot assign roles or self-promote', async () => {
  for (const uid of ['manager', 'member']) {
    await assertFails(assign(dbFor(uid), uid, 'owner'));
    await assertFails(assign(dbFor(uid), 'someone', 'member'));
  }
});
test('owner cannot be removed, demoted, replaced or duplicated', async () => {
  const db = dbFor('owner');
  await assertFails(remove(db, 'owner'));
  await assertFails(assign(db, 'owner', 'member'));
  await assertFails(assign(db, 'member', 'owner'));
  await assertFails(updateDoc(doc(db, 'farms/f1'), { ownerId: 'member', updatedAt: serverTimestamp() }));
});
test('one-sided role changes, inconsistent mirrors and partial deletions fail', async () => {
  const db = dbFor('owner');
  await assertFails(updateDoc(doc(db, 'farms/f1/members/member'), { role: 'manager', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'users/member/farms/f1'), { role: 'manager' }));
  await assertFails(deleteDoc(doc(db, 'farms/f1/members/member')));
  await assertFails(deleteDoc(doc(db, 'users/member/farms/f1')));
  const batch = writeBatch(db);
  batch.set(doc(db, 'farms/f1/members/member'), { uid: 'member', role: 'manager', updatedAt: serverTimestamp() });
  batch.set(doc(db, 'users/member/farms/f1'), { farmId: 'f1', role: 'member' });
  await assertFails(batch.commit());
});
test('atomic removal revokes subsequent reads and discovery', async () => {
  const db = dbFor('member');
  await assertSucceeds(getDoc(doc(db, 'farms/f1')));
  await assertSucceeds(remove(dbFor('owner'), 'member'));
  await assertFails(getDoc(doc(db, 'farms/f1')));
  assert.equal((await getDocs(collection(db, 'users/member/farms'))).size, 0);
});
test('staff rename; member cannot; fields and timestamps validated', async () => {
  for (const uid of ['owner', 'manager']) await assertSucceeds(updateDoc(doc(dbFor(uid), 'farms/f1'), { name: 'Renamed', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(dbFor('member'), 'farms/f1'), { name: 'Denied', updatedAt: serverTimestamp() }));
  const db = dbFor('owner');
  await assertFails(updateDoc(doc(db, 'farms/f1'), { name: '', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'farms/f1'), { name: 'Bad clock', updatedAt: Timestamp.fromMillis(0) }));
  await assertFails(updateDoc(doc(db, 'farms/f1'), { hiddenAdmin: true, updatedAt: serverTimestamp() }));
});
test('roster, discovery and global farm lists are scoped', async () => {
  const db = dbFor('member');
  await assertSucceeds(getDoc(doc(db, 'farms/f1/members/member')));
  await assertFails(getDocs(collection(db, 'farms/f1/members')));
  await assertFails(getDoc(doc(db, 'farms/f1/members/owner')));
  for (const uid of ['owner', 'manager']) await assertSucceeds(getDocs(collection(dbFor(uid), 'farms/f1/members')));
  await assertSucceeds(getDocs(collection(db, 'users/member/farms')));
  await assertFails(getDocs(collection(db, 'users/owner/farms')));
  await assertFails(getDocs(collection(db, 'farms')));
});
test('owner of another farm gains no cross-farm privileges', async () => {
  const db = dbFor('otherOwner');
  await assertSucceeds(createFarm(db, 'otherOwner', 'farm2'));
  await assertFails(assign(db, 'otherOwner', 'manager', 'f1'));
});
test('unverified member cannot use a granted membership', async () => {
  await assertSucceeds(assign(dbFor('owner'), 'futureMember', 'member'));
  await assertFails(getDoc(doc(dbFor('futureMember', false), 'farms/f1')));
});
test('client cannot fabricate audit or creation counters', async () => {
  const db = dbFor('owner');
  await assertFails(setDoc(doc(db, 'farms/f1/audit/fake'), { action: 'member.assigned' }));
  await assertFails(setDoc(doc(db, 'accountLimits/owner'), { ownedFarms: 0 }));
});
