import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';
import 'widgets/auth_header.dart';

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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(tagline: 'auth.login_tagline'.tr()),
                  const SizedBox(height: 32),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _forgotPassword,
                      child: Text('auth.forgot_password'.tr()),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
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
                  const _OrDivider(),
                  OutlinedButton.icon(
                    key: const Key('login_google_button'),
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text('auth.google_sign_in'.tr()),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('login_go_to_register_button'),
                    onPressed: () => context.push('/register'),
                    child: Text('auth.go_to_register'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Şifreli giriş ile Google girişi arasındaki "veya" ayracı.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('auth_or_divider'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'auth.or'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
