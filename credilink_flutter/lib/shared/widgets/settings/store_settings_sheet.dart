import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../auth/cred_text_field.dart';
import '../common/cred_avatar.dart';
import '../layout/cred_sheet_scaffold.dart';

class StoreSettingsSheet extends ConsumerStatefulWidget {
  const StoreSettingsSheet({super.key, required this.profile});

  final UserProfile profile;

  static Future<void> show(BuildContext context, UserProfile profile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StoreSettingsSheet(profile: profile),
    );
  }

  @override
  ConsumerState<StoreSettingsSheet> createState() => _StoreSettingsSheetState();
}

class _StoreSettingsSheetState extends ConsumerState<StoreSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _description;
  late final TextEditingController _permit;
  late final TextEditingController _hours;
  late final TextEditingController _facebook;
  late final TextEditingController _address;
  String? _storeImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController();
    _permit = TextEditingController();
    _hours = TextEditingController();
    _facebook = TextEditingController();
    _address = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final store = await ref.read(storeRepositoryProvider).getStore(widget.profile.id);
    if (!mounted || store == null) return;
    setState(() {
      _description.text = store.description ?? '';
      _permit.text = store.businessPermitNumber ?? '';
      _hours.text = store.businessHours ?? '';
      _facebook.text = store.facebookPage ?? '';
      _address.text = store.storeAddress ?? '';
      _storeImage = store.storeImage;
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _permit.dispose();
    _hours.dispose();
    _facebook.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _storeImage = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  @override
  Widget build(BuildContext context) {
    final storeName = widget.profile.storeName?.trim().isNotEmpty == true
        ? widget.profile.storeName!.trim()
        : 'My Store';

    return CredSheetScaffold(
      title: 'Store Settings',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: CredAvatar(name: storeName, imageUrl: _storeImage, radius: 44)),
            const SizedBox(height: CredTheme.spaceXs),
            Text(
              storeName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_storeImage == null || _storeImage!.isEmpty ? 'Upload store image' : 'Change store image'),
            ),
            if (_storeImage != null && _storeImage!.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _storeImage = ''),
                child: const Text('Remove image'),
              ),
            const SizedBox(height: CredTheme.spaceMd),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Store Description'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(controller: _address, label: 'Store Address', icon: Icons.location_on_outlined),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(controller: _permit, label: 'Business Permit #', icon: Icons.badge_outlined),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(controller: _hours, label: 'Business Hours', icon: Icons.schedule_outlined),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(controller: _facebook, label: 'Facebook Page', icon: Icons.facebook),
            const SizedBox(height: CredTheme.spaceMd),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Store Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(storeRepositoryProvider).updateStoreProfile(
            storeOwnerId: widget.profile.id,
            description: _description.text.trim(),
            storeAddress: _address.text.trim(),
            businessPermitNumber: _permit.text.trim(),
            businessHours: _hours.text.trim(),
            facebookPage: _facebook.text.trim(),
            storeImage: _storeImage,
            clearStoreImage: _storeImage == null || _storeImage!.isEmpty,
          );
      ref.invalidate(storeProfileProvider(widget.profile.id));
      ref.invalidate(receiptStoreInfoProvider(widget.profile.id));
      if (mounted) {
        Navigator.pop(context);
        CredSnackBar.show(context, 'Store settings saved');
      }
    } catch (e) {
      if (mounted) CredSnackBar.show(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
