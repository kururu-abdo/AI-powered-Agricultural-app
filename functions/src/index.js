import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { createFarmService } from './service.js';
import { PolicyError } from './policy.js';

initializeApp();
const service = createFarmService({
  db: getFirestore(), authAdmin: getAuth(), timestamp: () => FieldValue.serverTimestamp(),
});
const options = { region: 'us-central1', maxInstances: 10 };
function callable(method) {
  return onCall(options, async request => {
    try { return await service[method](request.auth, request.data); }
    catch (error) {
      if (error instanceof PolicyError) throw new HttpsError(error.code, error.message);
      // Avoid exposing database paths, email addresses or admin error details.
      throw new HttpsError('internal', 'The operation could not complete. Please retry.');
    }
  });
}
export const createFarm = callable('createFarm');
export const setFarmMember = callable('setFarmMember');
export const removeFarmMember = callable('removeFarmMember');
export const renameFarm = callable('renameFarm');
