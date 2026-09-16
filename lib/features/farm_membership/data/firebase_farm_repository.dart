import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/farm.dart';
import '../domain/farm_repository.dart';

class FirebaseFarmRepository implements FarmRepository {
  FirebaseFarmRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
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

  @override
  Future<void> createFarm(String id, String name) => _call('createFarm', {'farmId': id, 'name': name});
  @override
  Future<void> renameFarm(String id, String name) => _call('renameFarm', {'farmId': id, 'name': name});
  @override
  Future<void> setMember(String farmId, String uid, FarmRole role) =>
      _call('setFarmMember', {'farmId': farmId, 'uid': uid, 'role': role.name});
  @override
  Future<void> removeMember(String farmId, String uid) =>
      _call('removeFarmMember', {'farmId': farmId, 'uid': uid});

  Future<void> _call(String name, Map<String, Object> data) => _safe(() async {
    await _functions.httpsCallable(name).call<Object?>(data);
  });

  Future<T> _safe<T>(Future<T> Function() operation) async {
    try { return await operation(); }
    on FirebaseFunctionsException catch (error) {
      throw FarmFailure(switch (error.code) {
        'permission-denied' => 'You do not have permission for this operation.',
        'unauthenticated' => 'Sign in again to continue.',
        'failed-precondition' => 'Use an active verified member account. The owner cannot be changed.',
        'resource-exhausted' => 'Account limit reached. Please try again later.',
        'invalid-argument' => 'Check the farm name, member ID and role.',
        _ => 'Could not complete the request. Check your connection and retry.',
      });
    } on FirebaseException catch (_) {
      throw const FarmFailure('Could not load current farm access. Connect and refresh.');
    }
  }
}
