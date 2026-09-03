import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/cred_validators.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/forms/cred_form_field.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/common/info_banner.dart';

class AdminSystemTab extends ConsumerStatefulWidget {
  const AdminSystemTab({super.key});

  @override
  ConsumerState<AdminSystemTab> createState() => _AdminSystemTabState();
}

class _AdminSystemTabState extends ConsumerState<AdminSystemTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _region;
  late final TextEditingController _province;
  late final TextEditingController _municipality;
  late final TextEditingController _barangay;
  late final TextEditingController _sitioPurok;
  bool _editing = false;
  bool _saving = false;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _region = TextEditingController();
    _province = TextEditingController();
    _municipality = TextEditingController();
    _barangay = TextEditingController();
    _sitioPurok = TextEditingController();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _region.dispose();
    _province.dispose();
    _municipality.dispose();
    _barangay.dispose();
    _sitioPurok.dispose();
    super.dispose();
  }

  void _populate(UserProfile profile) {
    if (_profileId == profile.id) return;
    _profileId = profile.id;
    _fullName.text = profile.fullName;
    _email.text = profile.email ?? '';
    _phone.text = profile.phoneNumber ?? '';
    _region.text = profile.region ?? '';
    _province.text = profile.province;
    _municipality.text = profile.municipality;
    _barangay.text = profile.barangay;
    _sitioPurok.text = profile.sitioPurok ?? '';
  }

  Future<void> _save(UserProfile profile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
            userId: profile.id,
            fullName: _fullName.text,
            email: _email.text,
            phoneNumber: _phone.text,
            region: _region.text,
            province: _province.text,
            municipality: _municipality.text,
            barangay: _barangay.text,
            sitioPurok: _sitioPurok.text,
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
        _profileId = null;
      });
      CredSnackBar.show(context, 'Profile updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      CredSnackBar.show(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'Not logged in');
        _populate(p);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: CredAvatar(name: p.fullName, size: 72)),
            const SizedBox(height: 8),
            Center(
              child: Text(p.role.displayName, style: TextStyle(color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: Icon(
                  p.isActive ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: p.isActive ? Colors.green : Colors.red,
                ),
                label: Text(p.status),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editing)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _editing = false;
                              _profileId = null;
                              _populate(p);
                            }),
                    child: const Text('Cancel'),
                  ),
                FilledButton.tonal(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_editing) {
                            _save(p);
                          } else {
                            setState(() => _editing = true);
                          }
                        },
                  child: Text(_editing ? (_saving ? 'Saving…' : 'Save') : 'Edit Profile'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editing)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CredTextField(
                      controller: _fullName,
                      label: 'Full Name',
                      required: true,
                      validator: (v) => CredValidators.required(v, message: 'Enter your name'),
                    ),
                    const SizedBox(height: 12),
                    CredEmailField(controller: _email, required: false),
                    const SizedBox(height: 12),
                    CredPhoneField(controller: _phone),
                    const SizedBox(height: 12),
                    CredTextField(controller: _region, label: 'Region'),
                    const SizedBox(height: 12),
                    CredTextField(controller: _province, label: 'Province', required: true),
                    const SizedBox(height: 12),
                    CredTextField(controller: _municipality, label: 'Municipality', required: true),
                    const SizedBox(height: 12),
                    CredTextField(controller: _barangay, label: 'Barangay', required: true),
                    const SizedBox(height: 12),
                    CredTextField(controller: _sitioPurok, label: 'Sitio / Purok'),
                  ],
                ),
              )
            else ...[
              ListTile(title: const Text('Username'), subtitle: Text(p.username)),
              ListTile(title: const Text('Full Name'), subtitle: Text(p.fullName)),
              ListTile(title: const Text('Email'), subtitle: Text(p.email ?? 'N/A')),
              ListTile(title: const Text('Phone'), subtitle: Text(p.phoneNumber ?? 'N/A')),
              ListTile(
                title: const Text('Address'),
                subtitle: Text(
                  [p.sitioPurok, p.barangay, p.municipality, p.province]
                      .whereType<String>()
                      .where((e) => e.isNotEmpty)
                      .join(', '),
                ),
              ),
              if (p.createdAt != null)
                ListTile(
                  title: const Text('Member Since'),
                  subtitle: Text(DateFormat.yMMMd().format(p.createdAt!)),
                ),
            ],
            const SizedBox(height: 24),
            const InfoBanner(
              message:
                  'Password changes are handled through Firebase Auth. Use Forgot Password on the login screen to reset your password via email.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/forgot-password'),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Reset Password'),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }
}
