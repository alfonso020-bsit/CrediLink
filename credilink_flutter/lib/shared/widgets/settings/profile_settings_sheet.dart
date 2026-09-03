import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/cred_validators.dart';
import '../../../models/ph_address.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../address/ph_address_picker.dart';
import '../forms/cred_form_field.dart';
import '../layout/cred_sheet_scaffold.dart';

class ProfileSettingsSheet extends ConsumerStatefulWidget {
  const ProfileSettingsSheet({super.key, required this.profile});

  final UserProfile profile;

  static Future<void> show(BuildContext context, UserProfile profile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProfileSettingsSheet(profile: profile),
    );
  }

  @override
  ConsumerState<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends ConsumerState<ProfileSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _sitio;
  PhAddress? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _fullName = TextEditingController(text: p.fullName);
    _email = TextEditingController(text: p.email ?? '');
    _phone = TextEditingController(text: p.phoneNumber ?? '');
    _sitio = TextEditingController(text: p.sitioPurok ?? '');
    _address = PhAddress(
      region: p.region ?? '',
      province: p.province,
      municipality: p.municipality,
      barangay: p.barangay,
    );
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _sitio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CredSheetScaffold(
      title: 'Profile Settings',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredTextField(
              controller: _fullName,
              label: 'Full Name',
              icon: Icons.person_outline,
              required: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => CredValidators.required(v, message: 'Enter your name'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredEmailField(controller: _email, required: false),
            const SizedBox(height: CredTheme.spaceSm),
            CredPhoneField(controller: _phone),
            const SizedBox(height: CredTheme.spaceMd),
            PhAddressPicker(
              sitioController: _sitio,
              initial: _address,
              onChanged: (a) => _address = a,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredTextField(
              controller: _sitio,
              label: 'Sitio / Purok',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _address == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
            userId: widget.profile.id,
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            region: _address!.region,
            province: _address!.province,
            municipality: _address!.municipality,
            barangay: _address!.barangay,
            sitioPurok: _sitio.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        Navigator.pop(context);
        CredSnackBar.show(context, 'Profile updated');
      }
    } catch (e) {
      if (mounted) CredSnackBar.show(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
