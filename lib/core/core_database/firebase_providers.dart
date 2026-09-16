import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseEnabledProvider = Provider<bool>((ref) => false);

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  if (!ref.watch(firebaseEnabledProvider)) {
    throw StateError('Use main_firebase.dart to access Firebase.');
  }
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  if (!ref.watch(firebaseEnabledProvider)) {
    throw StateError('Use main_firebase.dart to access Firestore.');
  }
  return FirebaseFirestore.instance;
});
