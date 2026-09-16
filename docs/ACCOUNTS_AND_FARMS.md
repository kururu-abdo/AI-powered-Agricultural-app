# Accounts and farms — Firebase Auth + Firestore only

The app talks directly to Firebase Authentication and Cloud Firestore. There is
no Firebase Functions deployment, callable SDK, Admin SDK or custom backend.
`security_tests/` is a local emulator-test package, not a deployed service.

## 1. Account recovery and verification

On login, choose **Forgot password?**, enter an email and request a reset link.
Firebase hosts the password-change page. Existing and nonexistent accounts get
the same success message. Configure Email/Password, email templates and email
enumeration protection in Firebase Console.

Unverified accounts see the verification screen instead of farms. Choose **Send
verification email**, open the link, then **I verified my email**. The app reloads
the user and refreshes the ID token. Both UI and Firestore rules require verified
email; the UI alone never grants database access.

## 2. Farm permissions

| Action | Owner | Manager | Member |
| --- | --- | --- | --- |
| Read farm metadata | Yes | Yes | Yes |
| Read membership roster | Yes | Yes | Own membership only |
| Rename farm | Yes | Yes | No |
| Add/remove members | Yes | No | No |
| Assign manager/member | Yes | No | No |
| Remove/demote owner | No | No | No |

Any verified account can create a farm and becomes its owner. Ownership transfer
and farm deletion are not supported. An owner adds people using the account ID
shown on their farm screen; no invitation emails or global user lookup are used.

Rules cannot query Firebase Authentication for another user's current account
status. Owners must obtain the correct ID from the intended person. An assignment
can reference a nonexistent/unverified account, but only the matching signed-in,
verified account can use it. The former Admin SDK active-account lookup, farm
creation quota and generated audit events have been removed. Historical audit
records, if any, remain owner-readable and cannot be written by clients.
Firebase Auth token validity/refresh governs disabled or revoked sessions; rules
do not perform an immediate Admin SDK account-status check on each request.

## 3. Direct Firestore transactions

Read `lib/features/farm_membership/data/firebase_farm_repository.dart`, then
`firestore.rules`. Domain interfaces, Riverpod ViewModel and UI stay separate.

| Path | Purpose |
| --- | --- |
| `farms/{farmId}` | Farm name, immutable owner ID and creation time |
| `farms/{farmId}/members/{uid}` | Canonical membership role |
| `users/{uid}/farms/{farmId}` | User-specific discovery mirror |

**Create:** one online transaction writes the farm, owner membership and owner
mirror. Rules use `getAfter()` to require the full, consistent result. The owner
must be the authenticated verified caller. Partial bootstrap is rejected.

**Add/change role:** the owner writes membership and mirror in one transaction.
Rules enforce the caller's existing ownership, protect the owner record, limit
roles to manager/member and require matching post-commit values. An unchanged,
consistent mirror need not be rewritten by other compatible clients.

**Remove:** the owner deletes both membership and mirror atomically. One-sided
deletions fail. Removed members cannot perform subsequent server reads/mutations.

**Rename:** owner/manager can change only name and update timestamp. Owner ID and
creation timestamp cannot change. Required timestamps equal the server request
time, and names must be 2–80 characters. Client validation is only for usability;
Firestore rules enforce the security boundary even for modified clients.

Generated farm IDs support idempotent creation retries. The ViewModel retains an
ID during its lifetime; after a timeout and application restart, refresh the farm
list before creating again. This is not a durable offline outbox.

## 4. Offline boundary

Membership changes use transactions, which require connectivity. Membership reads
use `Source.server`. Old displayed data may remain until refresh, but never grants
server permission. The UI refreshes on resume and provides manual refresh.

Persistent Firestore caching remains disabled for this metadata-only release.
Startup clears the previous foundation cache before first use. No client offline
farm writes exist yet. Before adding crop records, replace this policy with
per-user encrypted offline storage and pending-write reconciliation. Firebase Auth
still persists its session; our code never caches passwords. Biometrics and
agricultural offline packs are future increments.

## 5. Setup

1. Generate Android/iOS wrappers if absent (see README.md).
2. Run FlutterFire configuration for your development project.
3. Enable Email/Password and configure email action templates in Firebase Console.
4. Create the Firestore database and deploy rules:

```bash
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter pub get
flutter run -t lib/main_firebase.dart
```

There is no Functions deployment or Functions-specific billing requirement.
No live Firebase settings or rules were changed by this code update. No Functions
were deployed in the earlier work, so no remote cleanup was needed. If you deployed
an earlier commit yourself, retire its four callable endpoints before production
use; do not keep the old backend and new client-managed rules active together.

## 6. Tests

```bash
npm --prefix security_tests ci
firebase emulators:exec --only firestore --project demo-agri-rules "npm --prefix security_tests test"
dart format lib test
flutter analyze
flutter test
```

The rules tests use authenticated client SDK transactions against the emulator;
Admin privileges are used only to seed fixtures through the test environment.
Coverage includes atomic bootstrap, concurrency/retry, tenant isolation, verified
email, role escalation, owner immutability, mirror consistency, removal and field
validation. All 15 emulator tests passed.
Flutter SDK is unavailable in the authoring environment, so mobile tests and real
email flows still require local validation.

## 7. Try it with two accounts

Verify accounts A and B. A creates a farm. B shares the account ID shown in the app.
A adds B as member; B refreshes. A promotes B to manager; B refreshes and can rename,
but cannot manage members. A removes B; B's next server access is rejected.

References:
- https://firebase.google.com/docs/auth/flutter/manage-users
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/security/rules-conditions
