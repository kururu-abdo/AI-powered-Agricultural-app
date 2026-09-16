import test from 'node:test';
import assert from 'node:assert/strict';
import { createFarmService } from '../src/service.js';

const auth = uid => ({ uid, token: { email_verified: true } });
function setup() {
  const data = new Map();
  const users = new Map(['owner', 'manager', 'member', 'outsider'].map(uid =>
    [uid, { uid, emailVerified: true, disabled: false }]));
  let sequence = 0;
  const db = {
    doc: path => ({ path }),
    collection: path => ({ doc: () => ({ path: `${path}/audit-${++sequence}` }) }),
    async runTransaction(action) {
      const staged = [];
      const tx = {
        get: async ref => ({ exists: data.has(ref.path), data: () => data.get(ref.path) }),
        create: (ref, value) => staged.push(() => {
          assert.equal(data.has(ref.path), false); data.set(ref.path, value);
        }),
        set: (ref, value) => staged.push(() => data.set(ref.path, value)),
        update: (ref, value) => staged.push(() => data.set(ref.path, { ...data.get(ref.path), ...value })),
        delete: ref => staged.push(() => data.delete(ref.path)),
      };
      await action(tx);
      staged.forEach(apply => apply());
    },
  };
  const service = createFarmService({ db, timestamp: () => 'timestamp', authAdmin: {
    async getUser(uid) {
      if (!users.has(uid)) throw Object.assign(new Error(), { code: 'auth/user-not-found' });
      return users.get(uid);
    },
  } });
  return { service, data, users };
}
const denied = (promise, code) => assert.rejects(promise, error => error.code === code);

test('bootstrap atomically writes owner, mirror and farm; retry is idempotent', async () => {
  const { service, data } = setup();
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'First farm' });
  assert.equal(data.get('farms/farm1').ownerId, 'owner');
  assert.equal(data.get('farms/farm1/members/owner').role, 'owner');
  assert.equal(data.get('users/owner/farms/farm1').role, 'owner');
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'Retry' });
  assert.equal(data.get('accountLimits/owner').ownedFarms, 1);
  assert.equal(data.get('farms/farm1').name, 'First farm');
  await denied(service.createFarm(auth('outsider'), { farmId: 'farm1', name: 'Hijack' }), 'already-exists');
});
test('membership mutations require live owner; owner cannot be demoted', async () => {
  const { service, data } = setup();
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'Farm' });
  await service.setFarmMember(auth('owner'), { farmId: 'farm1', uid: 'manager', role: 'manager' });
  await denied(service.setFarmMember(auth('manager'), { farmId: 'farm1', uid: 'outsider', role: 'manager' }), 'permission-denied');
  await denied(service.removeFarmMember(auth('owner'), { farmId: 'farm1', uid: 'owner' }), 'failed-precondition');
  await denied(service.setFarmMember(auth('owner'), { farmId: 'farm1', uid: 'owner', role: 'member' }), 'failed-precondition');
  assert.equal(data.has('users/outsider/farms/farm1'), false);
});
test('manager can rename; removed members lose server authority and discovery', async () => {
  const { service, data } = setup();
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'Farm' });
  await service.setFarmMember(auth('owner'), { farmId: 'farm1', uid: 'manager', role: 'manager' });
  await service.renameFarm(auth('manager'), { farmId: 'farm1', name: 'Renamed' });
  assert.equal(data.get('farms/farm1').name, 'Renamed');
  await service.removeFarmMember(auth('owner'), { farmId: 'farm1', uid: 'manager' });
  assert.equal(data.has('users/manager/farms/farm1'), false);
  await denied(service.renameFarm(auth('manager'), { farmId: 'farm1', name: 'Again' }), 'permission-denied');
});
test('unverified/disabled target and disabled actor are rejected without writes', async () => {
  const { service, data, users } = setup();
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'Farm' });
  users.get('member').emailVerified = false;
  await denied(service.setFarmMember(auth('owner'), { farmId: 'farm1', uid: 'member', role: 'member' }), 'failed-precondition');
  assert.equal(data.has('farms/farm1/members/member'), false);
  users.get('owner').disabled = true;
  await denied(service.renameFarm(auth('owner'), { farmId: 'farm1', name: 'Denied' }), 'permission-denied');
});
test('cross-farm owner cannot modify another farm', async () => {
  const { service } = setup();
  await service.createFarm(auth('owner'), { farmId: 'farm1', name: 'One' });
  await service.createFarm(auth('outsider'), { farmId: 'farm2', name: 'Two' });
  await denied(service.setFarmMember(auth('outsider'), { farmId: 'farm1', uid: 'member', role: 'manager' }), 'permission-denied');
});
