import 'farm.dart';

abstract interface class FarmRepository {
  String newFarmId();
  Future<List<Farm>> listFarms(String uid);
  Future<List<FarmMember>> listMembers(String farmId);
  Future<void> createFarm(String id, String name);
  Future<void> renameFarm(String id, String name);
  Future<void> setMember(String farmId, String uid, FarmRole role);
  Future<void> removeMember(String farmId, String uid);
}
