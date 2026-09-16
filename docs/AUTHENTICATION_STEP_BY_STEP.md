# Authentication — increment 1 (historical walkthrough)

This describes the first increment. Password reset, verification and farm roles
are now implemented; current setup and behavior are in
[Accounts and farms](ACCOUNTS_AND_FARMS.md). Use that guide for deployment and tests.

## Outcome and scope
Email/password signup, login, session-driven screen selection and logout are now
implemented. Farm membership, cooperative roles, email verification, password
reset, biometrics and offline access policy are separate subsequent increments.
No Firestore documents are created by signup. No authorization is inferred from
an authenticated identity. Firestore rules remain deny-all.

## Step 1 — Domain: define the contract
Read `lib/features/authentication/domain/entities/app_user.dart` and
`domain/repositories/auth_repository.dart`. AppUser contains identity only;
AuthRepository defines session observation and three account commands. These
files have no Flutter or Firebase dependency. `AuthFailure` exposes safe messages.

Read `domain/auth_validation.dart`: trim email but never passwords. Signup uses
an eight-character local minimum; Firebase's configured server policy remains
authoritative. Login accepts any nonempty password for existing accounts.

## Step 2 — Data: implement Firebase access
Read `data/repositories/firebase_auth_repository.dart`. Map Firebase User into
AppUser; translate error codes instead of displaying raw SDK errors. The adapter
is small enough to act as the data source directly; no forwarding-only classes.
Firebase signup also establishes a session. Session restoration and token refresh
belong to the Firebase SDK, not a custom password/token cache.

## Step 3 — Composition: wire Riverpod
Read `auth_providers.dart`. Bind AuthRepository to the Firebase implementation and
expose its session stream. Tests override the interface with an in-memory fake.
Provider composition is outside domain and presentation so SDK imports stay out
of the ViewModel and UI.

## Step 4 — ViewModel: manage commands
Read `presentation/view_models/auth_view_model.dart`. AsyncNotifier<void> holds
idle/loading/error state. It validates inputs again, blocks duplicate submissions,
and checks ref.mounted after async calls. Command completion never navigates:
only the session stream decides whether a user is signed in.

## Step 5 — View: render the state
Read `presentation/views/auth_screen.dart`, then `auth_gate.dart`. The form includes
password confirmation, disabled controls while busy, and readable failure messages.
Controllers are disposed when the form leaves the tree. AuthGate handles session
loading/error/signed-out/signed-in states. Logout returns to the form through the
session stream. An authenticated shell is NOT evidence of online authorization.
`lib/main.dart` still runs the data-free preview; `lib/main_firebase.dart` uses the gate.

## Step 6 — Configure and run
From the repository root, generate native wrappers if absent:

```bash
bash scripts/bootstrap.sh com.yourcompany
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios
```

Follow README.md's native Firebase configuration or generated-options setup.
In Firebase Console → Authentication → Sign-in method, enable Email/Password.
Then run:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -t lib/main_firebase.dart
```

Use a dedicated development Firebase project. No service account or server key
belongs in the mobile app. No console settings or remote rules were changed here.

## Step 7 — Verify behavior on a device
1. Open the Firebase entry point signed out: login form appears.
2. Try malformed email and mismatched confirmation: no signup request is sent.
3. Create a development account: session shell appears, account exists in Firebase.
4. Sign out, enter a wrong password: safe error appears and retry remains enabled.
5. Sign in correctly, restart: Firebase restores its persisted session.
6. Sign out, enable airplane mode, attempt login: connectivity failure is shown.
7. Restart offline with a persisted session: shell may appear; this is cached
   identity, not a new offline credential check or proof of current permissions.
8. Sign out: authenticated content disappears and back cannot reveal it.

The included five tests cover validation, duplicate requests/password preservation,
failed commands and retry, safe error mapping, and session-driven login/logout UI.
They use a fake repository, not the Firebase backend. Firebase adapter integration,
revocation behavior and device persistence still need emulator/device verification.
Flutter/Dart are unavailable in the authoring environment: these tests and the
analyzer have NOT been run here. Only static import and patch checks were run.

## Next: account recovery and verified identity, then farm ownership
Add password reset and email verification before production onboarding. Then build
trusted farm creation and membership, scoped rules plus emulator isolation tests.
Before reading actual farm data, implement shared-device cache/pending-write policy
and offline unlock rules. The current account switching is safe only for this
identity-only shell, which does not query or expose farm documents.

## References
- https://firebase.google.com/docs/auth/flutter/password-auth
- https://firebase.google.com/docs/auth/flutter/start
- https://riverpod.dev/docs/whats_new
