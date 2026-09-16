import 'package:agri_intelligence/features/farm_membership/domain/farm.dart';
import 'package:agri_intelligence/features/farm_membership/domain/farm_repository.dart';
import 'package:agri_intelligence/features/farm_membership/farm_providers.dart';
import 'package:agri_intelligence/features/farm_membership/presentation/view_models/farm_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFarmRepository implements FarmRepository {
  final ids = <String>[];
  bool fail = true;
  int sequence = 0;
  @override
  String newFarmId() => 'farm-${++sequence}';
  @override
  Future<void> createFarm(String id, String name) async {
    ids.add(id);
    if (fail) throw const FarmFailure('Connection interrupted.');
  }
  @override
  Future<List<Farm>> listFarms(String uid) async => [];
  @override
  Future<List<FarmMember>> listMembers(String farmId) async => [];
  @override
  Future<void> renameFarm(String id, String name) async {}
  @override
  Future<void> removeMember(String farmId, String uid) async {}
  @override
  Future<void> setMember(String farmId, String uid, FarmRole role) async {}
}

void main() {
  test('create retries reuse request ID after a lost response', () async {
    final fake = FakeFarmRepository();
    final container = ProviderContainer.test(overrides: [
      farmRepositoryProvider.overrideWithValue(fake),
    ]);
    final subscription = container.listen(farmViewModelProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(farmViewModelProvider.future);
    final vm = container.read(farmViewModelProvider.notifier);
    expect(await vm.createFarm('Farm'), isFalse);
    fake.fail = false;
    expect(await vm.createFarm('Farm'), isTrue);
    expect(fake.ids, ['farm-1', 'farm-1']);
    expect(await vm.createFarm('Another farm'), isTrue);
    expect(fake.ids.last, 'farm-2');
  });

  test('role capabilities match UI contract; server remains authoritative', () {
    const owner = Farm(id: 'f', name: 'F', role: FarmRole.owner);
    const manager = Farm(id: 'f', name: 'F', role: FarmRole.manager);
    const member = Farm(id: 'f', name: 'F', role: FarmRole.member);
    expect(owner.canManageMembers, isTrue);
    expect(manager.canManageMembers, isFalse);
    expect(manager.canRename, isTrue);
    expect(member.canRename, isFalse);
  });
}
