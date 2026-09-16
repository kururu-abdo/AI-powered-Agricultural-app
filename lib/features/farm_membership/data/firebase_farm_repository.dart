import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/farm.dart';
import '../domain/farm_repository.dart';

class FirebaseFarmRepository implements FarmRepository {
  FirebaseFarmRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _server = GetOptions(source: Source.server);

  @override
  String newFarmId() => _db.collection('farms').doc().id;

  @override
  Future<List<Farm>> listFarms(String uid) => _safe(() async {
    final index = await _db.collection('users').doc(uid).collection('farms').get(_server);
    return Future.wait(index.docs.map((entry) async {
      final farmRef = _db.collection('farms').doc(entry.id);
      final farm = await farmRef.get(_server);
      final member = await farmRef.collection('members').doc(uid).get(_server);
      final data = farm.data();
      final membership = member.data();
      if (data == null || membership == null) {
        throw const FarmFailure('Membership changed. Refresh your farms.');
      }
      // The discovery mirror is not an authorization source.
      return Farm(id: entry.id, name: data['name'] as String,
          role: FarmRole.values.byName(membership['role'] as String));
    }));
  });

  @override
  Future<List<FarmMember>> listMembers(String farmId) => _safe(() async {
    final snapshot = await _db.collection('farms').doc(farmId).collection('members').get(_server);
    return snapshot.docs.map((doc) => FarmMember(uid: doc.id,
        role: FarmRole.values.byName(doc.data()['role'] as String))).toList();
  });

  String _uid() {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw const FarmFailure('Sign in with a verified account first.');
    }
    return user.uid;
  }

  String _name(String value) {
    final name = value.trim();
    if (name.length < 2 || name.length > 80) {
      throw const FarmFailure('Farm name must have 2–80 characters.');
    }
    return name;
  }

  @override
  Future<void> createFarm(String id, String name) => _safe(() async {
    final uid = _uid();
    final value = _name(name);
    final farm = _db.collection('farms').doc(id);
    try {
      await _db.runTransaction<void>((tx) async {
        final existing = await tx.get(farm);
        if (existing.exists) {
          if (existing.data()?['ownerId'] != uid) {
            throw const FarmFailure('This farm ID is already in use.');
          }
          return; // Same-ID retry after a lost response.
        }
        tx.set(farm, {
          'name': value, 'ownerId': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(farm.collection('members').doc(uid), {
          'uid': uid, 'role': 'owner', 'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection('users').doc(uid).collection('farms').doc(id),
            {'farmId': id, 'role': 'owner'});
      });
    } on FirebaseException catch (error) {
      // Concurrent identical creates can be rejected by immutable-owner rules
      // before the SDK retries. Confirm the committed owner using a server read.
      if (error.code != 'permission-denied' && error.code != 'aborted') rethrow;
      final committed = await farm.get(_server);
      if (committed.data()?['ownerId'] != uid) rethrow;
    }
  });

  @override
  Future<void> renameFarm(String id, String name) => _safe(() async {
    _uid();
    final value = _name(name);
    final farm = _db.collection('farms').doc(id);
    await _db.runTransaction<void>((tx) async {
      await tx.get(farm); // Online transaction; rules enforce role at commit.
      tx.update(farm, {'name': value, 'updatedAt': FieldValue.serverTimestamp()});
    });
  });

  @override
  Future<void> setMember(String farmId, String uid, FarmRole role) => _safe(() async {
    _uid();
    if (uid.isEmpty || uid.contains('/') || uid.length > 128 ||
        role == FarmRole.owner) {
      throw const FarmFailure('Use a valid account ID and member or manager role.');
    }
    final farm = _db.collection('farms').doc(farmId);
    await _db.runTransaction<void>((tx) async {
      await tx.get(farm);
      tx.set(farm.collection('members').doc(uid), {
        'uid': uid, 'role': role.name, 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_db.collection('users').doc(uid).collection('farms').doc(farmId),
          {'farmId': farmId, 'role': role.name});
    });
  });

  @override
  Future<void> removeMember(String farmId, String uid) => _safe(() async {
    _uid();
    final farm = _db.collection('farms').doc(farmId);
    await _db.runTransaction<void>((tx) async {
      await tx.get(farm);
      tx.delete(farm.collection('members').doc(uid));
      tx.delete(_db.collection('users').doc(uid).collection('farms').doc(farmId));
    });
  });

  Future<T> _safe<T>(Future<T> Function() operation) async {
    try { return await operation(); }
    on FirebaseException catch (error) {
      throw FarmFailure(switch (error.code) {
        'permission-denied' => 'Access denied. Check your role and refresh farm access.',
        'unauthenticated' => 'Sign in again to continue.',
        _ => 'Could not complete the request. Connect and retry.',
      });
    }
  }
}
