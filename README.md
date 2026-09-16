# Agri Intelligence

Flutter agricultural intelligence foundation using MVVM, Riverpod, Firebase Auth
and Cloud Firestore. Android and iOS are the initial targets.

Implemented: email/password signup and login, password reset, email verification,
session gate, logout, farm creation, membership, owner/manager/member permissions,
direct Firestore transactions and role-enforcing security rules.
No Firebase Functions or custom backend is used.

AI diagnosis, advisor/RAG, weather, crop planning, offline agricultural packs,
biometric unlock and media synchronization are still planned.

## Run the preview

Install Flutter stable and platform tooling (Xcode on macOS for iOS).
If `android/` and `ios/` do not yet exist:

```bash
bash scripts/bootstrap.sh com.yourcompany
```

The script generates native wrappers without overwriting the authored Dart files.
Use your reverse-domain organization before registering Firebase apps. On Windows,
run this script through Git Bash. Native wrappers were not generated in the
authoring environment because the Flutter SDK is unavailable.

```bash
flutter pub get
flutter run
```

`main.dart` is a data-free preview. It does not bypass authentication for farm data.

## Connect Firebase and run the application

Install Firebase CLI, then:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios
```

Select your development Firebase project, create a Firestore database, and enable
Email/Password in Firebase Authentication. Configure reset/verification templates.
The client initially uses native Android/iOS Firebase configuration. Ensure
FlutterFire generated and linked `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`.

If using generated Dart options instead, update
`lib/core/core_database/initialize_firebase.dart`:

```dart
import '../../firebase_options.dart';
// Replace Firebase.initializeApp() inside initializeFirebase():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Keep the remaining database initialization in that function. Do not include
service-account credentials or backend secrets in the app.

Farm management uses Firestore directly. Follow [Accounts and farms](docs/ACCOUNTS_AND_FARMS.md)
for transaction design, security rules and setup. Deploy the rules to your development project:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter run -t lib/main_firebase.dart
```

No Functions deployment is needed. No live Firebase resources or settings were
changed by this code update.

## Verification

```bash
dart format lib test
flutter analyze
flutter test
npm --prefix security_tests ci
firebase emulators:exec --only firestore --project demo-agri-rules "npm --prefix security_tests test"
```

The local security test package validates direct client operations against actual
Firestore rules. It is not a backend service. All 15 rules/transaction emulator
tests passed, including concurrent creation and atomic membership changes. Flutter analyzer, nine Flutter tests and mobile/email flows
remain unverified here because Flutter SDK is unavailable. Commit `pubspec.lock`
after successful local dependency resolution. Test dependencies are locked in
`security_tests/package-lock.json`.

## Learn it step by step

1. [Initial authentication architecture](docs/AUTHENTICATION_STEP_BY_STEP.md)
2. [Password recovery, verification, farms and roles](docs/ACCOUNTS_AND_FARMS.md)
3. [Architecture and offline boundaries](docs/ARCHITECTURE.md)

Farm membership is online-authoritative. Persistent Firestore caching is currently
disabled; encrypted offline crop/guide/model storage will be added separately.
