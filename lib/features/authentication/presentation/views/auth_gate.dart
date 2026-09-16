import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../farm_membership/presentation/views/farms_screen.dart';
import '../../auth_providers.dart';
import 'auth_screen.dart';
import 'verification_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authSessionProvider).when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(body: Center(child: FilledButton(
        onPressed: () => ref.invalidate(authSessionProvider),
        child: const Text('Could not restore session. Retry'),
      ))),
      data: (user) {
        if (user == null) return const AuthScreen();
        if (!user.emailVerified) return VerificationScreen(user: user, key: ValueKey(user.id));
        return FarmsScreen(user: user, key: ValueKey(user.id));
      },
    );
  }
}
