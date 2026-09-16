# Agri Intelligence

Flutter agricultural intelligence foundation using MVVM, Riverpod, Firebase Auth
and Cloud Firestore. Android and iOS are the initial targets.

Implemented: email/password signup and login, password reset, email verification,
session gate, logout, farm creation, membership, owner/manager/member permissions,
trusted callable mutations, audit metadata and Firestore rules.

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

Farm management needs callable functions. Install Node.js 22 and follow
[Accounts and farms](docs/ACCOUNTS_AND_FARMS.md) for tests and deployment.
From the root, after configuring the intended development project:

```bash
npm --prefix functions ci
firebase deploy --only functions:membership,firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter run -t lib/main_firebase.dart
```

Cloud Functions deployment requires the Blaze plan. No live Firebase resources or
billing settings were changed by this code update. Local emulators can test the
backend without a production deployment.

## Verification

```bash
dart format lib test
flutter analyze
flutter test
npm --prefix functions test
firebase emulators:exec --only firestore --project demo-agri-rules "npm --prefix functions run test:emulator"
```

Executed: 9 backend tests, 6 Firestore rules tests, 1 real transaction test; all
passed. JavaScript imports/syntax, JSON and local Dart imports checked.
Not executed: Flutter analyzer, 9 Flutter tests and mobile device/email flows;
Flutter SDK is unavailable here. Resolve dependencies and commit `pubspec.lock`
once Flutter validation succeeds. Backend versions are recorded in
`functions/package-lock.json`.

## Learn it step by step

1. [Initial authentication architecture](docs/AUTHENTICATION_STEP_BY_STEP.md)
2. [Password recovery, verification, farms and roles](docs/ACCOUNTS_AND_FARMS.md)
3. [Architecture and offline boundaries](docs/ARCHITECTURE.md)

Farm membership is online-authoritative. Persistent Firestore caching is currently
disabled; encrypted offline crop/guide/model storage will be added separately.
