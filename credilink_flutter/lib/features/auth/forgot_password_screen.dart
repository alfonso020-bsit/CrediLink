import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/cred_theme.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/forms/cred_form_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(_email.text);
      if (!mounted) return;
      CredSnackBar.show(context, 'If an account exists, we sent a reset link.');
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
      welcomeTitle: 'Reset password',
      welcomeSubtitle: 'Enter your email to receive a reset link',
      showBack: true,
      onBack: () => context.go('/login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredEmailField(
              controller: _email,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredPrimaryButton(
              label: 'Send reset link',
              onPressed: _loading ? null : _submit,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
