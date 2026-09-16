import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/domain/entities/app_user.dart';
import '../../../authentication/presentation/view_models/auth_view_model.dart';
import '../../domain/farm.dart';
import '../../farm_providers.dart';
import '../view_models/farm_view_model.dart';

class FarmsScreen extends ConsumerStatefulWidget {
  const FarmsScreen({required this.user, super.key});
  final AppUser user;
  @override
  ConsumerState<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends ConsumerState<FarmsScreen> with WidgetsBindingObserver {
  String? _selectedId;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }
  void _refresh() {
    ref.invalidate(farmsProvider(widget.user.id));
    ref.invalidate(farmMembersProvider);
  }
  Future<String?> _textInput(String title, String label, {String initial = ''}) =>
      showDialog<String>(context: context, builder: (_) => _TextInputDialog(
        title: title, label: label, initial: initial,
      ));
  Future<void> _create() async {
    final name = await _textInput('Create farm', 'Farm name');
    if (!mounted || name == null) return;
    await ref.read(farmViewModelProvider.notifier).createFarm(name);
  }
  Future<void> _rename(Farm farm) async {
    final name = await _textInput('Rename farm', 'Farm name', initial: farm.name);
    if (!mounted || name == null) return;
    await ref.read(farmViewModelProvider.notifier).renameFarm(farm.id, name);
  }
  Future<void> _add(Farm farm) async {
    final uid = await _textInput('Add member', 'Member account ID');
    if (!mounted || uid == null) return;
    await ref.read(farmViewModelProvider.notifier).setMember(farm.id, uid, FarmRole.member);
  }
  Future<void> _remove(Farm farm, FarmMember member) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Remove member?'), content: Text(member.uid),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ));
    if (!mounted || confirmed != true) return;
    await ref.read(farmViewModelProvider.notifier).removeMember(farm.id, member.uid);
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(farmsProvider(widget.user.id));
    final command = ref.watch(farmViewModelProvider);
    final auth = ref.watch(authViewModelProvider);
    final busy = command.isLoading || auth.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('My farms'), actions: [
        IconButton(tooltip: 'Refresh access', onPressed: busy ? null : _refresh,
            icon: const Icon(Icons.refresh)),
        TextButton(onPressed: busy ? null : () async {
          // Explicitly drop in-memory farm results before switching identities.
          ref.invalidate(farmsProvider);
          ref.invalidate(farmMembersProvider);
          await ref.read(authViewModelProvider.notifier).signOut();
        }, child: const Text('Sign out')),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.user.email ?? 'Verified account'),
        const Text('Your account ID — share it with the farm owner to join:'),
        SelectableText(widget.user.id),
        const SizedBox(height: 16),
        const Text('Connect to refresh farm access or manage memberships.'),
        if (command.error != null) Text(command.error.toString()),
        if (auth.error != null) Text(auth.error.toString()),
        FilledButton(onPressed: busy ? null : _create, child: const Text('Create farm')),
        farms.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Farm access could not be loaded. Connect and refresh.'),
          data: (items) {
            Farm? selected;
            for (final farm in items) {
              if (farm.id == _selectedId) selected = farm;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (items.isEmpty) const Text('No farms yet. Create one or ask an owner to add your account ID.'),
              for (final farm in items)
                Card(child: ListTile(
                  title: Text(farm.name), subtitle: Text(farm.role.name),
                  selected: farm.id == _selectedId,
                  onTap: busy ? null : () => setState(() => _selectedId = farm.id),
                )),
              if (selected != null) _details(selected, busy),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _details(Farm farm, bool busy) {
    final members = farm.role == FarmRole.member ? null
        : ref.watch(farmMembersProvider((widget.user.id, farm.id)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(),
      Text(farm.name, style: Theme.of(context).textTheme.titleLarge),
      Text('Your role: ${farm.role.name}'),
      if (farm.canRename) OutlinedButton(onPressed: busy ? null : () => _rename(farm),
          child: const Text('Rename farm')),
      if (farm.canManageMembers) OutlinedButton(onPressed: busy ? null : () => _add(farm),
          child: const Text('Add member by account ID')),
      if (members != null) members.when(
        skipLoadingOnRefresh: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Could not load members. Refresh access.'),
        data: (items) => Column(children: [
          for (final member in items) Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SelectableText(member.uid), Text(member.role.name),
              if (farm.canManageMembers && member.role != FarmRole.owner) Wrap(children: [
                TextButton(onPressed: busy ? null : () => ref.read(farmViewModelProvider.notifier)
                    .setMember(farm.id, member.uid,
                        member.role == FarmRole.member ? FarmRole.manager : FarmRole.member),
                    child: Text(member.role == FarmRole.member ? 'Make manager' : 'Make member')),
                TextButton(onPressed: busy ? null : () => _remove(farm, member), child: const Text('Remove')),
              ]),
            ]),
          )),
        ]),
      ),
    ]);
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({required this.title, required this.label, required this.initial});
  final String title;
  final String label;
  final String initial;
  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _controller,
        decoration: InputDecoration(labelText: widget.label)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save')),
    ],
  );
}
