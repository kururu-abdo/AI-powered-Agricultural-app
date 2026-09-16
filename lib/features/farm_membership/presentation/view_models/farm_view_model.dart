import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/farm.dart';
import '../../farm_providers.dart';

final farmViewModelProvider = AsyncNotifierProvider.autoDispose<FarmViewModel, void>(FarmViewModel.new);

class FarmViewModel extends AsyncNotifier<void> {
  String? _pendingCreateId;
  @override
  FutureOr<void> build() {}

  Future<bool> createFarm(String name) {
    final repository = ref.read(farmRepositoryProvider);
    // Retain the ID on failure so a lost response does not duplicate the farm.
    _pendingCreateId ??= repository.newFarmId();
    return _run(() async {
      await repository.createFarm(_pendingCreateId!, name.trim());
      _pendingCreateId = null;
    });
  }
  Future<bool> renameFarm(String id, String name) => _run(() =>
      ref.read(farmRepositoryProvider).renameFarm(id, name.trim()));
  Future<bool> setMember(String id, String uid, FarmRole role) => _run(() =>
      ref.read(farmRepositoryProvider).setMember(id, uid.trim(), role));
  Future<bool> removeMember(String id, String uid) => _run(() =>
      ref.read(farmRepositoryProvider).removeMember(id, uid));

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (!ref.mounted) return false;
      ref.invalidate(farmsProvider);
      ref.invalidate(farmMembersProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error is FarmFailure ? error
          : const FarmFailure('Could not complete the operation. Please retry.'), stack);
      return false;
    }
  }
}
