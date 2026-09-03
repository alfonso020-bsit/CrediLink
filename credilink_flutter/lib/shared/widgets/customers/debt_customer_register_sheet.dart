import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_validators.dart';
import '../../../models/ph_address.dart';
import '../address/ph_address_picker.dart';
import '../forms/cred_form_field.dart';
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
              textInputAction: TextInputAction.next,
              validator: (v) => CredValidators.required(v, message: 'Enter your name'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredEmailField(controller: _emailController),
            const SizedBox(height: CredTheme.spaceSm),
            CredPhoneField(controller: _phoneController),
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
