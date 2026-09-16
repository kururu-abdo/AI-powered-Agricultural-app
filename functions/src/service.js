import { actorUid, documentId, farmName, memberRole, authorize, protectOwner, fail } from './policy.js';

// Dependency-injected service, shared by callable handlers and emulator tests.
export function createFarmService({ db, authAdmin, timestamp }) {
  const farmRef = id => db.doc(`farms/${id}`);
  const memberRef = (id, uid) => db.doc(`farms/${id}/members/${uid}`);
  const indexRef = (uid, id) => db.doc(`users/${uid}/farms/${id}`);
  const audit = (tx, id, actorId, action, details = {}) => {
    tx.create(db.collection(`farms/${id}/audit`).doc(), {
      actorId, action, ...details, createdAt: timestamp(),
    });
  };
  async function activeActor(auth) {
    const uid = actorUid(auth);
    const user = await authAdmin.getUser(uid);
    if (user.disabled || !user.emailVerified) fail('permission-denied', 'Account access denied.');
    return uid;
  }
  async function requireAccess(tx, id, uid, action) {
    const farm = await tx.get(farmRef(id));
    const member = await tx.get(memberRef(id, uid));
    authorize(farm.data(), member.data(), uid, action);
    return farm.data();
  }
  return {
    async createFarm(auth, data) {
      const uid = await activeActor(auth);
      const id = documentId(data?.farmId, 'Farm ID');
      const name = farmName(data?.name);
      await db.runTransaction(async tx => {
        const existing = await tx.get(farmRef(id));
        if (existing.exists) {
          if (existing.data().ownerId !== uid) fail('already-exists', 'Choose a new farm ID.');
          return; // Lost-response retry: never creates a second farm.
        }
        const quotaRef = db.doc(`accountLimits/${uid}`);
        const quota = await tx.get(quotaRef);
        const owned = quota.data()?.ownedFarms ?? 0;
        if (owned >= 20) fail('resource-exhausted', 'Farm creation limit reached.');
        tx.create(farmRef(id), { name, ownerId: uid, createdAt: timestamp(), updatedAt: timestamp() });
        tx.create(memberRef(id, uid), { uid, role: 'owner', updatedAt: timestamp() });
        tx.create(indexRef(uid, id), { farmId: id, role: 'owner' });
        tx.set(quotaRef, { ownedFarms: owned + 1 });
        audit(tx, id, uid, 'farm.created');
      });
      return { farmId: id };
    },
    async setFarmMember(auth, data) {
      const uid = await activeActor(auth);
      const id = documentId(data?.farmId, 'Farm ID');
      const targetUid = documentId(data?.uid, 'Member ID');
      const role = memberRole(data?.role);
      await db.runTransaction(async tx => {
        const farm = await requireAccess(tx, id, uid, 'manageMembers');
        protectOwner(farm, targetUid);
        // Authorize before checking another account to avoid outsider enumeration.
        let target;
        try { target = await authAdmin.getUser(targetUid); }
        catch (error) {
          if (error.code === 'auth/user-not-found') fail('failed-precondition', 'Member account is unavailable.');
          throw error;
        }
        if (target.disabled || !target.emailVerified) {
          fail('failed-precondition', 'Member must have an active, verified account.');
        }
        tx.set(memberRef(id, targetUid), { uid: targetUid, role, updatedAt: timestamp() });
        tx.set(indexRef(targetUid, id), { farmId: id, role });
        audit(tx, id, uid, 'member.assigned', { targetUid, role });
      });
      return { ok: true };
    },
    async removeFarmMember(auth, data) {
      const uid = await activeActor(auth);
      const id = documentId(data?.farmId, 'Farm ID');
      const targetUid = documentId(data?.uid, 'Member ID');
      await db.runTransaction(async tx => {
        const farm = await requireAccess(tx, id, uid, 'manageMembers');
        protectOwner(farm, targetUid);
        tx.delete(memberRef(id, targetUid));
        tx.delete(indexRef(targetUid, id));
        audit(tx, id, uid, 'member.removed', { targetUid });
      });
      return { ok: true };
    },
    async renameFarm(auth, data) {
      const uid = await activeActor(auth);
      const id = documentId(data?.farmId, 'Farm ID');
      const name = farmName(data?.name);
      await db.runTransaction(async tx => {
        await requireAccess(tx, id, uid, 'rename');
        tx.update(farmRef(id), { name, updatedAt: timestamp() });
        audit(tx, id, uid, 'farm.renamed');
      });
      return { ok: true };
    },
  };
}
