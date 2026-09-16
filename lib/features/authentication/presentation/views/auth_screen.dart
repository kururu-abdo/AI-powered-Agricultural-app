import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_validation.dart';
import '../../domain/entities/auth_failure.dart';
import '../view_models/auth_view_model.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signingUp = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref.read(authViewModelProvider).isLoading) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(authViewModelProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
          signingUp: _signingUp,
        );
  }

  @override
  Widget build(BuildContext context) {
    final command = ref.watch(authViewModelProvider);
    final busy = command.isLoading;
    final error = command.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Agri Intelligence')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_signingUp ? 'Create your account' : 'Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('An internet connection is needed to sign in '
                        'or create an account.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: AuthValidation.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: _signingUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_signingUp) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                          onPressed: busy ? null : () => setState(() {
                            _hidePassword = !_hidePassword;
                          }),
                          icon: Icon(_hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) => AuthValidation.password(
                          value, signingUp: _signingUp),
                    ),
                    if (_signingUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirm,
                        enabled: !busy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value == _password.text
                            ? null : 'Passwords do not match.',
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(error is AuthFailure
                            ? error.message : 'Please try again.',
                            style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(busy ? 'Please wait…'
                          : _signingUp ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () {
                        ref.read(authViewModelProvider.notifier).clearError();
                        _form.currentState?.reset();
                        _password.clear();
                        _confirm.clear();
                        setState(() => _signingUp = !_signingUp);
                      },
                      child: Text(_signingUp
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
