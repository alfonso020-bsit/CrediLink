import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../models/ph_address.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/address/ph_address_picker.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/auth/cred_password_field.dart';
import '../../shared/widgets/auth/cred_text_field.dart';
import '../../shared/widgets/auth/role_selector.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _storeName = TextEditingController();
  final _sitio = TextEditingController();
  late UserRole _role;
  PhAddress? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole ?? UserRole.customer;
  }

  @override
  void dispose() {
    for (final c in [_username, _fullName, _email, _phone, _password, _confirm, _storeName, _sitio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_address == null) {
      CredSnackBar.show(context, 'Please complete your address', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).register(RegisterData(
            role: _role,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
            phoneNumber: _phone.text,
            region: _address!.region,
            province: _address!.province,
            municipality: _address!.municipality,
            barangay: _address!.barangay,
            sitioPurok: _sitio.text,
            storeName: _storeName.text,
          ));
      if (!mounted) return;
      CredSnackBar.show(context, 'Account created! Please log in.');
      final roleParam = _role == UserRole.storeOwner ? 'storeowner' : 'customer';
      context.go('/login?role=$roleParam');
    } on AuthException catch (e) {
      if (mounted) CredSnackBar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      appBarTitle: 'Registration',
      welcomeTitle: 'Create Account',
      welcomeSubtitle: 'Register as Customer or Store Owner',
      showBack: true,
      onBack: () => context.go('/login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoleSelector(
              roles: const [UserRole.customer, UserRole.storeOwner],
              selectedRole: _role,
              style: RoleSelectorStyle.toggle,
              onChanged: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: 20),
            CredTextField(controller: _username, label: 'Username', icon: Icons.alternate_email, validator: _req, required: true),
            const SizedBox(height: 16),
            CredTextField(controller: _fullName, label: 'Full Name', icon: Icons.person, validator: _req, required: true),
            const SizedBox(height: 16),
            CredTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v != null && v.contains('@') ? null : 'Valid email required',
              required: true,
            ),
            const SizedBox(height: 16),
            CredTextField(controller: _phone, label: 'Phone', icon: Icons.phone_outlined),
            const SizedBox(height: 16),
            CredPasswordField(
              controller: _password,
              validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),
            const SizedBox(height: 16),
            CredPasswordField(
              controller: _confirm,
              label: 'Confirm Password',
              validator: (v) => v == _password.text ? null : 'Passwords do not match',
            ),
            if (_role == UserRole.storeOwner) ...[
              const SizedBox(height: 16),
              CredTextField(controller: _storeName, label: 'Store Name', icon: Icons.storefront_outlined, validator: _req, required: true),
            ],
            const SizedBox(height: 20),
            const Text(
              'Address',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            PhAddressPicker(onChanged: (PhAddress a) => _address = a, sitioController: _sitio),
            const SizedBox(height: 12),
            CredTextField(controller: _sitio, label: 'Sitio / Purok (optional)', icon: Icons.place_outlined),
            const SizedBox(height: 24),
            CredPrimaryButton(
              label: 'Create Account',
              icon: Icons.person_add_outlined,
              onPressed: _loading ? null : _register,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  String? _req(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;
}

UserRole? roleFromQuery(String? role) {
  switch (role?.toLowerCase()) {
    case 'customer':
      return UserRole.customer;
    case 'storeowner':
      return UserRole.storeOwner;
    default:
      return null;
  }
}
