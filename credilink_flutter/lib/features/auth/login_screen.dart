import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_role_footer.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/auth/cred_password_field.dart';
import '../../shared/widgets/auth/cred_text_field.dart';
import '../../shared/widgets/auth/role_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? UserRole.customer;
  }

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
            selectedRole: _selectedRole,
          );
      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      CredSnackBar.show(context, 'Welcome back, ${profile.fullName}!');
      context.go(profile.role.initialTabRoute);
    } on AuthException catch (e) {
      if (mounted) CredSnackBar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      appBarTitle: 'Login',
      welcomeTitle: 'Welcome Back',
      welcomeSubtitle: 'Login to your account',
      showBack: true,
      onBack: () => context.go('/home'),
      formFooter: AuthRoleFooter(selectedRole: _selectedRole),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoleSelector(
              roles: UserRole.values,
              selectedRole: _selectedRole,
              style: RoleSelectorStyle.grid,
              onChanged: (r) => setState(() => _selectedRole = r),
            ),
            const SizedBox(height: 20),
            CredTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v != null && v.contains('@') ? null : 'Valid email required',
            ),
            const SizedBox(height: 16),
            CredPasswordField(
              controller: _passwordController,
              onFieldSubmitted: (_) => _onLogin(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : () => context.go('/forgot-password'),
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 8),
            CredPrimaryButton(
              label: 'Login as ${_selectedRole.displayName}',
              icon: Icons.login,
              onPressed: _isLoading ? null : _onLogin,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
