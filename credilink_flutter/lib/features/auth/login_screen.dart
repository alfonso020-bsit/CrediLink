import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/platform/post_login_route.dart';
import '../../core/theme/cred_theme.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_footer.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/forms/cred_form_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      CredSnackBar.show(context, 'Welcome back, ${profile.fullName}!');
      context.go(postLoginRoute(profile.role));
    } on AuthException catch (e) {
      if (mounted) CredSnackBar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      welcomeTitle: kIsWeb ? null : 'Welcome back',
      welcomeSubtitle: kIsWeb ? null : 'Sign in to continue',
      showBack: true,
      onBack: () => context.go('/home'),
      formFooter: kIsWeb ? null : const AuthFooter(),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CredEmailField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CredTheme.spaceMd),
              CredPasswordField(
                controller: _passwordController,
                onFieldSubmitted: (_) => _onLogin(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: CredTheme.spaceXs),
              CredPrimaryButton(
                label: kIsWeb ? 'Sign in' : 'Log in',
                icon: Icons.login,
                onPressed: _isLoading ? null : _onLogin,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
