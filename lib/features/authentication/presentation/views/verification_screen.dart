import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_failure.dart';
import '../view_models/auth_view_model.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({required this.user, super.key});
  final AppUser user;
  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  String? _notice;
  DateTime? _lastSent;

  Future<void> _send() async {
    // Local UX throttle only; Firebase enforces server-side rate limits.
    if (_lastSent != null && DateTime.now().difference(_lastSent!).inSeconds < 60) {
      setState(() => _notice = 'Please wait a minute before requesting another email.');
      return;
    }
    await ref.read(authViewModelProvider.notifier).sendVerification();
    if (!mounted) return;
    if (!ref.read(authViewModelProvider).hasError) {
      setState(() {
        _lastSent = DateTime.now();
        _notice = 'Verification email sent. Open the link, then return here.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final command = ref.watch(authViewModelProvider);
    final error = command.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Verify ${widget.user.email ?? 'your email'} before accessing farms.'),
        const SizedBox(height: 20),
        FilledButton(onPressed: command.isLoading ? null : _send,
            child: const Text('Send verification email')),
        OutlinedButton(onPressed: command.isLoading ? null
            : () => ref.read(authViewModelProvider.notifier).refreshVerification(),
            child: const Text('I verified my email')),
        TextButton(onPressed: command.isLoading ? null
            : () => ref.read(authViewModelProvider.notifier).signOut(),
            child: const Text('Sign out')),
        if (_notice != null) Text(_notice!),
        if (error != null) Text(error is AuthFailure ? error.message : 'Please retry.'),
      ]),
    );
  }
}
