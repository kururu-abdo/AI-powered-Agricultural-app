import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_database/firebase_providers.dart';
import '../../domain/entities/feature_module.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final firebaseEnabled = ref.watch(firebaseEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Agri Intelligence')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Your farm. In the field.',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(firebaseEnabled
                ? 'Firebase initialized • Foundation stage'
                : 'Local preview • Firebase not connected'),
            const SizedBox(height: 8),
            const Text('We will build each module step by step. '
                'Agricultural features are not implemented yet.'),
            const SizedBox(height: 24),
            for (final module in FeatureModule.values)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.grass),
                  title: Text(module.title),
                  subtitle: Text(module.description),
                  trailing: const Icon(Icons.chevron_right),
                  selected: state.selectedModule == module,
                  onTap: () => ref
                      .read(homeViewModelProvider.notifier)
                      .selectModule(module),
                ),
              ),
            if (state.selectedModule case final module?) ...[
              const SizedBox(height: 16),
              Text('${module.title} — planned',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text('This module has its own domain, data and '
                  'presentation folders ready for implementation.'),
            ],
          ],
        ),
      ),
    );
  }
}
