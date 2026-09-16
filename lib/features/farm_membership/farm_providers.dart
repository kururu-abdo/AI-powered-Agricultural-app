import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core_database/firebase_providers.dart';
import 'data/firebase_farm_repository.dart';
import 'domain/farm.dart';
import 'domain/farm_repository.dart';

final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FirebaseFarmRepository(ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider));
});

final farmsProvider = FutureProvider.autoDispose.family<List<Farm>, String>((ref, uid) {
  return ref.watch(farmRepositoryProvider).listFarms(uid);
});

// Include identity in the key to prevent sharing results across sessions.
final farmMembersProvider = FutureProvider.autoDispose
    .family<List<FarmMember>, (String, String)>((ref, key) {
  return ref.watch(farmRepositoryProvider).listMembers(key.$2);
});
