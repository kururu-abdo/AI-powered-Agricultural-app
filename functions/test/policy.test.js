import test from 'node:test';
import assert from 'node:assert/strict';
import { actorUid, documentId, farmName, memberRole, authorize, protectOwner } from '../src/policy.js';
const farm = { ownerId: 'owner' };
const rejects = (fn, code) => assert.throws(fn, error => error.code === code);

test('authentication and verified claim required', () => {
  rejects(() => actorUid(null), 'unauthenticated');
  rejects(() => actorUid({ uid: 'u', token: {} }), 'permission-denied');
  assert.equal(actorUid({ uid: 'u', token: { email_verified: true } }), 'u');
});
test('reject path traversal and unsupported roles', () => {
  for (const value of ['../farm', 'a/b', '', null]) rejects(() => documentId(value), 'invalid-argument');
  rejects(() => memberRole('owner'), 'invalid-argument');
  rejects(() => farmName(' '), 'invalid-argument');
  assert.equal(farmName(' My farm '), 'My farm');
});
test('only owner manages membership, managers rename, members cannot', () => {
  authorize(farm, { role: 'owner' }, 'owner', 'manageMembers');
  authorize(farm, { role: 'manager' }, 'manager', 'rename');
  rejects(() => authorize(farm, { role: 'manager' }, 'manager', 'manageMembers'), 'permission-denied');
  rejects(() => authorize(farm, { role: 'member' }, 'member', 'rename'), 'permission-denied');
  rejects(() => authorize(farm, null, 'outsider', 'rename'), 'permission-denied');
});
test('owner role alone cannot spoof farm ownership', () => {
  rejects(() => authorize(farm, { role: 'owner' }, 'imposter', 'manageMembers'), 'permission-denied');
  rejects(() => protectOwner(farm, 'owner'), 'failed-precondition');
});
