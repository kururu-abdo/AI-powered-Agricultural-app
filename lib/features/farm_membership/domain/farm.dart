enum FarmRole { owner, manager, member }

class Farm {
  const Farm({required this.id, required this.name, required this.role});
  final String id;
  final String name;
  final FarmRole role;
  bool get canRename => role == FarmRole.owner || role == FarmRole.manager;
  bool get canManageMembers => role == FarmRole.owner;
}

class FarmMember {
  const FarmMember({required this.uid, required this.role});
  final String uid;
  final FarmRole role;
}

class FarmFailure implements Exception {
  const FarmFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
