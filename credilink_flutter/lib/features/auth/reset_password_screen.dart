import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/cred_theme.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../core/utils/cred_validators.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/forms/cred_form_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.oobCode});

  final String oobCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;
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
      welcomeTitle: 'New password',
      welcomeSubtitle: 'Enter your new password',
      showBack: true,
      onBack: () => context.go('/login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredPasswordField(
              controller: _password,
              newPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredPasswordField(
              controller: _confirm,
              label: 'Confirm password',
              newPassword: true,
              validator: (v) => CredValidators.confirmPassword(v, _password.text),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredPrimaryButton(
              label: 'Update password',
              onPressed: _loading ? null : _submit,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
