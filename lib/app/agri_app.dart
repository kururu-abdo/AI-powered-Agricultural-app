import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core_database/firebase_providers.dart';
import '../features/authentication/presentation/views/auth_gate.dart';
import '../features/home/presentation/views/home_screen.dart';
import 'theme/app_theme.dart';

class AgriApp extends ConsumerWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'Agri Intelligence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ref.watch(firebaseEnabledProvider)
            ? const AuthGate()
            : const HomeScreen(),
      );
}
