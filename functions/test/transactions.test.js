import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { createFarmService } from '../src/service.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required.');
const app = initializeApp({ projectId: 'demo-agri-transactions' }, 'transactions');
const db = getFirestore(app);
const service = createFarmService({ db, timestamp: () => FieldValue.serverTimestamp(), authAdmin: {
  async getUser(uid) { return { uid, emailVerified: true, disabled: false }; },
} });
const auth = uid => ({ uid, token: { email_verified: true } });
after(async () => { await db.terminate(); await deleteApp(app); });

test('concurrent bootstrap retries create one farm and one quota increment', async () => {
  const farmId = `farm_${Date.now()}`;
  const uid = `owner_${Date.now()}`;
  await Promise.all(Array.from({ length: 3 }, () =>
    service.createFarm(auth(uid), { farmId, name: 'Concurrent farm' })));
  const [farm, member, index, quota] = await Promise.all([
    db.doc(`farms/${farmId}`).get(), db.doc(`farms/${farmId}/members/${uid}`).get(),
    db.doc(`users/${uid}/farms/${farmId}`).get(), db.doc(`accountLimits/${uid}`).get(),
  ]);
  assert.equal(farm.data().ownerId, uid);
  assert.equal(member.data().role, 'owner');
  assert.equal(index.data().role, 'owner');
  assert.equal(quota.data().ownedFarms, 1);
  await service.setFarmMember(auth(uid), { farmId, uid: 'manager', role: 'manager' });
  await service.removeFarmMember(auth(uid), { farmId, uid: 'manager' });
  assert.equal((await db.doc(`farms/${farmId}/members/manager`).get()).exists, false);
  assert.equal((await db.doc(`users/manager/farms/${farmId}`).get()).exists, false);
  await assert.rejects(service.renameFarm(auth('manager'), { farmId, name: 'Denied' }),
    error => error.code === 'permission-denied');
});
