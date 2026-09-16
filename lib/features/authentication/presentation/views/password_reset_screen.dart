import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_validation.dart';
import '../../domain/entities/auth_failure.dart';
import '../view_models/auth_view_model.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});
  @override
  ConsumerState<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _notice;
  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _notice = null);
    await ref.read(authViewModelProvider.notifier).sendPasswordReset(_email.text);
    if (!mounted) return;
    if (!ref.read(authViewModelProvider).hasError) {
      setState(() => _notice = 'If an account exists for this email, '
          'you will receive a password reset link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final command = ref.watch(authViewModelProvider);
    final error = command.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Form(key: _form, child: TextFormField(
          controller: _email,
          enabled: !command.isLoading,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: AuthValidation.email,
        )),
        const SizedBox(height: 20),
        FilledButton(onPressed: command.isLoading ? null : _send,
            child: const Text('Send reset link')),
        if (_notice != null) Text(_notice!),
        if (error != null) Text(error is AuthFailure ? error.message : 'Please retry.'),
      ]),
    );
  }
}
