import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Android/iOS. Offline agronomic packs will use a separate local store.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  // This release has no queued farm writes. Remove any legacy foundation cache
  // before opening Firestore, then keep authorization metadata memory-only.
  await firestore.clearPersistence();
  firestore.settings = const Settings(persistenceEnabled: false);
}
