# Account recovery, verification, membership and roles

This increment follows the first authentication module. The account flow is now:
signed out → login/signup → email verification → farm selection and management.
The local preview (`main.dart`) still contains no Firebase-backed data.

## 1. Password reset

On the login screen choose **Forgot password?**. Enter an email and request a reset
link. Firebase hosts the password-change page; no password change happens in our
client. The success text is deliberately the same for existing and nonexistent
accounts. Network/rate-limit errors remain actionable. Firebase sends the email;
no mail service credentials are in the app.

Read `password_reset_screen.dart`, `AuthViewModel.sendPasswordReset`, and
`FirebaseAuthRepository.sendPasswordReset`. Enable Email/Password and configure
email templates in Firebase Console. Enable email enumeration protection for the
project as an additional service-side control. Custom deep links are not required:
the user opens Firebase's hosted action page, then returns to the app.

## 2. Email verification

New and existing unverified users see a verification screen, never the farm screen.
Choose **Send verification email**, open the link, then **I verified my email**.
The app reloads the user and forces an ID-token refresh so the server receives the
updated `email_verified` claim. The session stream uses `idTokenChanges`.

Sending is an explicit action, not a side effect of every widget rebuild. Resends
have a local one-minute throttle; Firebase applies actual service-side limits.
This is verified identity, not proof of any farm role. A signed-in user can always
sign out from the verification screen.

## 3. Farm domain and roles

| Capability | Owner | Manager | Member |
| --- | --- | --- | --- |
| Read own farm metadata | Yes | Yes | Yes |
| Read membership roster | Yes | Yes | No; own membership only |
| Rename farm | Yes | Yes | No |
| Add/remove members | Yes | No | No |
| Assign manager/member role | Yes | No | No |
| Read backend audit events | Yes | No | No |
| Remove/demote owner | No | No | No |

A verified user may create a farm and becomes its owner. Each account may create
up to 20 farms in this increment. Ownership transfer and farm deletion are deferred.
Membership is farm-scoped: a manager in farm A gains no rights in farm B.

The UI shows **Your account ID**. An owner adds an existing verified account using
that ID, then can promote it to manager or remove it. This is direct membership
assignment, not an email invitation flow; no invitation is sent. The owner must
obtain the ID from the intended person. No global user search or email lookup is
exposed. Members refresh their farm list to see newly granted access.

## 4. Data model and backend

| Path | Purpose | Writes |
| --- | --- | --- |
| `farms/{farmId}` | Name, owner ID, timestamps | Callable functions |
| `farms/{farmId}/members/{uid}` | Canonical farm role | Callable functions |
| `users/{uid}/farms/{farmId}` | User-scoped discovery mirror | Same transaction as membership |
| `farms/{farmId}/audit/{eventId}` | Actor/action/time metadata | Callable functions |
| `accountLimits/{uid}` | Farm creation quota | Callable functions only |

`functions/src/policy.js` validates identity and role permissions.
`service.js` performs transactions. `index.js` exposes four authenticated callables:
`createFarm`, `renameFarm`, `setFarmMember`, `removeFarmMember`.
The service also checks that the caller's Auth account is active and verified.
Membership changes re-read current farm ownership and membership inside the same
transaction as the mutation. Client Firestore writes are denied, including for
owners; Admin SDK writes are guarded by the service policy instead of client rules.

Create requests use a client-generated farm ID. A retry with the same ID returns
the existing owned farm and does not increment quota again. The Flutter ViewModel
retains this ID for retries during its lifetime; it is not a durable offline outbox.
After a timeout/restart, refresh farms before creating again. Farm metadata and
member changes require connectivity and are never queued as offline writes.

## 5. Offline and shared-device boundary

This release has only identity and authorization metadata, not crop records.
Farm reads use `Source.server`; no cached role authorizes a request. Client-side
controls improve UX; functions and rules enforce access independently.
Data already displayed can remain visible until refresh; refresh also runs when
the app resumes. A removal blocks subsequent server reads/mutations immediately
once the transaction commits, but cannot erase data someone already saw.

Persistent Firestore caching is disabled for this increment, and the previous
foundation cache is cleared before opening Firestore. This is intentional for
shared devices and is not a complete offline-first agricultural data solution.
There are currently no queued Firestore client writes to lose. Before adding
crop records or any offline queue, replace this startup clearing policy with
explicit per-user encrypted storage, pending-write handling and offline packs.
Riverpod farm/member results are scoped by user and disposed or invalidated on
logout. Firebase Auth still manages its persisted session; passwords are never
cached by our code. Biometrics and offline unlock policy remain a later increment.

## 6. Setup and deployment

Use the Firebase project already connected through FlutterFire. Generate native
wrappers with `bash scripts/bootstrap.sh com.yourcompany` only if absent.
Email reset and verification work with Authentication alone; membership additionally
requires a Firestore database and deployed callable functions and rules.

From the repository root:

```bash
flutter pub get
npm --prefix functions ci
npm --prefix functions test
firebase emulators:exec --only firestore --project demo-agri-rules "npm --prefix functions run test:emulator"
flutter analyze
flutter test
```

Use Node.js 22 for deployment. Backend tests here ran on Node 24.19.0; the configured
production runtime is Node 22. Local emulator tests were run with Firebase CLI
13.35.1 and Java 17; newer CLI/emulator releases may need a newer Java runtime.
The emulator command uses demo projects and does not touch live data.

When ready to deploy to your development project:

```bash
firebase login
firebase deploy --only functions:membership,firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter run -t lib/main_firebase.dart
```

Cloud Functions deployment requires the Firebase Blaze billing plan. Local tests
and emulators do not require a production deployment. No remote Firebase project,
rules, billing settings, functions or email templates were changed by this work.

Both functions and Flutter use `us-central1`. Choose an appropriate region before
first deployment and change both `functions/src/index.js` and `farm_providers.dart`
together if needed. Read README.md for native/generated Firebase options setup.
App Check is not wired in this increment; add and test client attestation before
enabling callable enforcement for public production rollout.

## 7. Acceptance walkthrough

1. Create account A. Before verification, confirm only verification controls appear.
2. Request verification, open the email, return and refresh verification.
3. Create a farm as A; see role `owner`.
4. Create and verify account B. Copy B's account ID.
5. Sign in as A; add B as member. B refreshes and sees the farm read-only.
6. A promotes B to manager. B refreshes and can rename but cannot add members.
7. A removes B. B refreshes and loses access. A remains owner.
8. Try password reset with an existing and nonexistent email: same success text.
9. Disconnect while refreshing farm access: show a connection/access error rather
   than treating an old role as current authority.

## Verification evidence

- Nine backend policy/service tests passed.
- Six Firestore emulator rules tests passed, including self-promotion attempts,
  tenant isolation, unverified users, discovery isolation and revocation.
- One real Firestore emulator transaction test passed: concurrent create retries
  produce one farm/owner/mirror/quota increment; removal deletes both membership
  and discovery mirror and rejects subsequent management actions.
- Callable module imports and JavaScript syntax validated.
- Seven Flutter authentication tests are included, plus farm tests. Flutter SDK
  is unavailable here, so Flutter tests, analyzer and device flows remain unverified.
- These tests do not exercise real email delivery or deployed callable HTTP transport.

## Official references

- https://firebase.google.com/docs/auth/flutter/manage-users
- https://firebase.google.com/docs/functions/callable
- https://firebase.google.com/docs/functions/get-started
- https://firebase.google.com/docs/firestore/security/rules-conditions
