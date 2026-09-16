import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/views/home_screen.dart';
import '../../auth_providers.dart';
import '../../domain/entities/auth_failure.dart';
import '../view_models/auth_view_model.dart';
import 'auth_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final command = ref.watch(authViewModelProvider);
    return session.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(authSessionProvider),
            child: const Text('Could not restore session. Retry'),
          ),
        ),
      ),
      data: (user) {
        if (user == null) return const AuthScreen();
        final error = command.error;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                ListTile(
                  title: Text(user.email ?? 'Signed in'),
                  subtitle: const Text('Account session • Farm access coming next'),
                  trailing: TextButton(
                    onPressed: command.isLoading ? null
                        : () => ref.read(authViewModelProvider.notifier).signOut(),
                    child: const Text('Sign out'),
                  ),
                ),
                if (error != null)
                  Text(error is AuthFailure ? error.message : 'Please try again.'),
                // Recreate user-scoped widgets when the identity changes.
                Expanded(child: HomeScreen(key: ValueKey(user.id))),
              ],
            ),
          ),
        );
      },
    );
  }
}
