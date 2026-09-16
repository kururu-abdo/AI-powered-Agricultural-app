import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/feature_module.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

class HomeState {
  const HomeState({this.selectedModule});
  final FeatureModule? selectedModule;
}

/// Riverpod's Notifier IS the ViewModel; no second state management layer.
class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  void selectModule(FeatureModule module) {
    state = HomeState(selectedModule: module);
  }
}
