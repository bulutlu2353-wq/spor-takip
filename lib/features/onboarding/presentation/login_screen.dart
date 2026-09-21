import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      setState(() => _errorMessage = _messageForAuthError(error));
    } catch (_) {
      setState(() => _errorMessage = 'auth.unknown_error'.tr());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'auth.enter_email_first'.tr());
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.reset_email_sent'.tr())),
        );
      }
    } catch (_) {
      setState(() => _errorMessage = 'auth.unknown_error'.tr());
    }
  }

  String _messageForAuthError(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'auth.invalid_credentials'.tr();
      default:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login_screen'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('auth.login_title'.tr(), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              key: const Key('login_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('login_submit_button'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('auth.login_button'.tr()),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _forgotPassword,
              child: Text('auth.forgot_password'.tr()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('login_google_button'),
              onPressed: _isSubmitting
                  ? null
                  : () => ref.read(authRepositoryProvider).signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: Text('auth.google_sign_in'.tr()),
            ),
            TextButton(
              key: const Key('login_go_to_register_button'),
              onPressed: () => context.push('/register'),
              child: Text('auth.go_to_register'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
