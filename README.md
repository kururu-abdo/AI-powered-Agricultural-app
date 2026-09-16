# Agri Intelligence — Flutter foundation

Increment 0: MVVM + Riverpod + feature-first structure, Firebase Authentication
and Cloud Firestore wiring, a local preview screen, and conservative Firestore rules.
Android and iOS are the initial targets. No authentication UI, AI inference, weather,
planner, media upload or custom sync engine is implemented in this increment.

## 1. Generate platform projects and run the preview

Install current stable Flutter, Android tooling, and Xcode for iOS on macOS.
Extract this archive and open a terminal in `agri_intelligence`:

```bash
bash scripts/bootstrap.sh com.yourcompany
flutter run
```

Replace `com.yourcompany` with your reverse-domain organization before registering
Firebase apps. The script generates Android/iOS wrappers with your installed SDK
in a temporary directory, then copies only the native projects into this scaffold.
It preserves the authored Dart code and pubspec. The default is `com.example`.
On Windows, use Git Bash for the script. Native wrappers are not included because
Flutter is unavailable in the environment where this scaffold was authored.

The preview runs `lib/main.dart` with no Firebase initialization and shows planned
modules. Tap a module to exercise the Riverpod ViewModel. This is not an auth bypass:
no farm data or repository implementation is accessible from the preview.

## 2. Connect your Firebase project

Install the Firebase CLI using the official setup guide, then:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios
```

Select/create your Firebase project. In the Firebase console, create a Cloud
Firestore database and enable Email/Password authentication for the next increment.
Choose the database region deliberately before creation.

This scaffold initializes Firebase using the native Android/iOS configuration.
Ensure FlutterFire created `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` and linked them to the respective apps.
If FlutterFire only generated `lib/firebase_options.dart`, update
`lib/core/core_database/initialize_firebase.dart` with:

```dart
import '../../firebase_options.dart';
// Inside initializeFirebase(), replace Firebase.initializeApp():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Then run the Firebase entry point:

```bash
flutter run -t lib/main_firebase.dart
```

A successful startup means the SDK initialized; it does not mean the device is
online, a user is authenticated or server rules have been deployed.
Never put service-account credentials or AI API secrets in this application.

## 3. Apply the baseline rules to a NEW development project

```bash
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
```

These rules deny every read/write. Do not deploy over an existing application's
rules. Feature-specific access will be added with authentication and tenant rules.
No Firebase resources or rules were remotely created/deployed by this deliverable.

## 4. Verify locally

```bash
dart format lib
flutter analyze
flutter run
flutter run -t lib/main_firebase.dart
```

Check the preview with airplane mode enabled; select a module and confirm its
planned status. Configure Firebase, run the Firebase entry point, and confirm it
shows initialization status. Incorrect configuration should show a setup message.

Validation here: archive integrity, local Dart import resolution, JSON parsing and
shell syntax checked. Flutter/Dart SDKs are unavailable, so dependency resolution,
Dart analyzer, compilation and device behavior are NOT verified. Run the commands
above before building on this foundation. Commit the generated pubspec.lock after
successful resolution to reproduce dependency versions.

## Next increment: Authentication

1. Plain-Dart AppUser and farm membership entities; AuthRepository contract.
2. Firebase data source and repository implementation.
3. Riverpod AsyncNotifier login/signup ViewModels and validation.
4. Login, signup, session gate and logout UI.
5. Trusted farm bootstrap and membership/role security rules.
6. Emulator tests for tenant isolation, role escalation and auth failures.
7. Offline session policy, shared-device cache cleanup and biometric unlock.

See `docs/ARCHITECTURE.md` for offline and security boundaries.

## Official references
- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/firestore/manage-data/enable-offline
- https://firebase.google.com/docs/auth/flutter/start
- https://riverpod.dev/docs/introduction/getting_started
