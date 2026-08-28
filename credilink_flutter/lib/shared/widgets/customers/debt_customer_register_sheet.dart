import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/ph_address.dart';
import '../address/ph_address_picker.dart';
import '../auth/cred_text_field.dart';
import '../layout/cred_sheet_scaffold.dart';

class DebtCustomerRegisterResult {
  const DebtCustomerRegisterResult({
    required this.fullName,
    required this.email,
    this.phone,
    this.province,
    this.municipality,
    this.barangay,
  });

  final String fullName;
  final String email;
  final String? phone;
  final String? province;
  final String? municipality;
  final String? barangay;
}

class DebtCustomerRegisterSheet extends StatefulWidget {
  const DebtCustomerRegisterSheet({super.key});

  static Future<DebtCustomerRegisterResult?> show(BuildContext context) {
    return showModalBottomSheet<DebtCustomerRegisterResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DebtCustomerRegisterSheet(),
    );
  }

  @override
  State<DebtCustomerRegisterSheet> createState() => _DebtCustomerRegisterSheetState();
}

class _DebtCustomerRegisterSheetState extends State<DebtCustomerRegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sitioController = TextEditingController();
  PhAddress? _address;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _sitioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CredSheetScaffold(
      title: 'Register Customer',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create a customer account for this debt sale.'),
            const SizedBox(height: CredTheme.spaceMd),
            CredTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              required: true,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              required: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            PhAddressPicker(
              sitioController: _sitioController,
              onChanged: (a) => _address = a,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Register & Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _address == null) return;
    Navigator.pop(
      context,
      DebtCustomerRegisterResult(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        province: _address!.province,
        municipality: _address!.municipality,
        barangay: _address!.barangay,
      ),
    );
  }
}
