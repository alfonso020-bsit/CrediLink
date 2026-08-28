import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/auth/cred_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(_email.text);
      if (!mounted) return;
      CredSnackBar.show(context, 'Reset email sent if account exists.');
      context.go('/login');
    } on AuthException catch (e) {
      if (mounted) CredSnackBar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      appBarTitle: 'Forgot Password',
      welcomeTitle: 'Reset Password',
      welcomeSubtitle: 'Enter your email to receive a reset link',
      showBack: true,
      onBack: () => context.go('/login'),
      child: Column(
        children: [
          CredTextField(
            controller: _email,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          CredPrimaryButton(label: 'Send Reset Link', onPressed: _submit, isLoading: _loading),
        ],
      ),
    );
  }
}
