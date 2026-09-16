export class PolicyError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
export function fail(code, message) { throw new PolicyError(code, message); }
export function actorUid(auth) {
  if (!auth?.uid) fail('unauthenticated', 'Sign in to continue.');
  if (auth.token?.email_verified !== true) {
    fail('permission-denied', 'Verify your email before accessing farms.');
  }
  return documentId(auth.uid, 'User ID');
}
export function documentId(value, label = 'ID') {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    fail('invalid-argument', `${label} is invalid.`);
  }
  return value;
}
export function farmName(value) {
  if (typeof value !== 'string' || value.trim().length < 2 || value.trim().length > 80) {
    fail('invalid-argument', 'Farm name must have 2–80 characters.');
  }
  return value.trim();
}
export function memberRole(value) {
  if (!['manager', 'member'].includes(value)) {
    fail('invalid-argument', 'Choose manager or member.');
  }
  return value;
}
export function authorize(farm, membership, uid, action) {
  if (!farm || !membership || !['owner', 'manager', 'member'].includes(membership.role)) {
    fail('permission-denied', 'Farm access denied.');
  }
  const owner = farm.ownerId === uid && membership.role === 'owner';
  if (action === 'manageMembers' && !owner) {
    fail('permission-denied', 'Only the owner can manage memberships.');
  }
  if (action === 'rename' && !owner && membership.role !== 'manager') {
    fail('permission-denied', 'Only the owner or a manager can rename the farm.');
  }
}
export function protectOwner(farm, targetUid) {
  if (farm.ownerId === targetUid) {
    fail('failed-precondition', 'The owner cannot be removed or demoted.');
  }
}
