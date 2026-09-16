import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Android/iOS only. FlutterFire supplies native Firebase configuration.
/// Initialization does not verify server reachability or authentication.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 40 * 1024 * 1024,
  );
}
