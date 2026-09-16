import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/agri_app.dart';
import 'core/core_database/firebase_providers.dart';
import 'core/core_database/initialize_firebase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeFirebase();
    runApp(ProviderScope(
      overrides: [firebaseEnabledProvider.overrideWithValue(true)],
      child: const AgriApp(),
    ));
  } catch (_) {
    // Do not expose credentials, platform exceptions, or farm data in the UI.
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Firebase could not start. Check the configuration '
                'steps in README.md, then restart the app.'),
          ),
        ),
      ),
    ));
  }
}
