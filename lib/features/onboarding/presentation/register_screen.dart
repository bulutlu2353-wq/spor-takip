import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'auth.passwords_dont_match'.tr());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
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

  String _messageForAuthError(AuthException error) {
    switch (error.code) {
      case 'user_already_exists':
        return 'auth.email_already_registered'.tr();
      case 'weak_password':
        return 'auth.weak_password'.tr();
      default:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('register_screen'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'auth.register_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('register_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('register_confirm_password_field'),
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.confirm_password_label'.tr()),
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
              key: const Key('register_submit_button'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('auth.register_button'.tr()),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('auth.go_to_login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
