import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/cred_theme.dart';
import '../../core/utils/cred_snackbar.dart';
import '../../core/utils/cred_validators.dart';
import '../../models/ph_address.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/address/ph_address_picker.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/auth/role_selector.dart';
import '../../shared/widgets/forms/cred_form_field.dart';

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
      welcomeTitle: 'Create account',
      welcomeSubtitle: 'Register as a Customer or Store Owner',
      showBack: true,
      onBack: () => context.go('/login'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('Account type'),
              RoleSelector(
                roles: const [UserRole.customer, UserRole.storeOwner],
                selectedRole: _role,
                onChanged: (r) => setState(() => _role = r),
              ),
              const SizedBox(height: CredTheme.spaceLg),
              const _SectionLabel('Account'),
              CredTextField(
                controller: _username,
                label: 'Username',
                icon: Icons.alternate_email,
                required: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => CredValidators.required(v, message: 'Enter your username'),
              ),
              const SizedBox(height: CredTheme.spaceMd),
              CredEmailField(controller: _email),
              const SizedBox(height: CredTheme.spaceMd),
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
              ),
              const SizedBox(height: CredTheme.spaceLg),
              const _SectionLabel('Your details'),
              CredTextField(
                controller: _fullName,
                label: 'Full name',
                icon: Icons.person_outline,
                required: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => CredValidators.required(v, message: 'Enter your name'),
              ),
              const SizedBox(height: CredTheme.spaceMd),
              CredPhoneField(controller: _phone),
              if (_role == UserRole.storeOwner) ...[
                const SizedBox(height: CredTheme.spaceMd),
                CredTextField(
                  controller: _storeName,
                  label: 'Store name',
                  icon: Icons.storefront_outlined,
                  required: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => CredValidators.required(v, message: 'Enter your store name'),
                ),
              ],
              const SizedBox(height: CredTheme.spaceLg),
              const _SectionLabel('Address'),
              PhAddressPicker(
                onChanged: (PhAddress a) => _address = a,
                sitioController: _sitio,
              ),
              const SizedBox(height: CredTheme.spaceMd),
              CredTextField(
                controller: _sitio,
                label: 'Sitio / Purok',
                icon: Icons.place_outlined,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: CredTheme.spaceLg),
              CredPrimaryButton(
                label: 'Create account',
                icon: Icons.person_add_outlined,
                onPressed: _loading ? null : _register,
                isLoading: _loading,
              ),
              const SizedBox(height: CredTheme.spaceMd),
              TextButton(
                onPressed: _loading ? null : () => context.go('/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CredTheme.spaceSm),
      child: Text(text, style: CredTheme.sectionTitle(context)),
    );
  }
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
