import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/auth/cred_password_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.oobCode});

  final String oobCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      CredSnackBar.show(context, 'Passwords do not match', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(
            code: widget.oobCode,
            newPassword: _password.text,
          );
      if (!mounted) return;
      CredSnackBar.show(context, 'Password updated. Please log in.');
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
      appBarTitle: 'Reset Password',
      welcomeTitle: 'New Password',
      welcomeSubtitle: 'Enter your new password',
      child: Column(
        children: [
          CredPasswordField(controller: _password),
          const SizedBox(height: 12),
          CredPasswordField(controller: _confirm, label: 'Confirm Password'),
          const SizedBox(height: 16),
          CredPrimaryButton(label: 'Update Password', onPressed: _submit, isLoading: _loading),
        ],
      ),
    );
  }
}
