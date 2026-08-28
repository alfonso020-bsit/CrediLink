import 'package:flutter/material.dart';

import '../auth/cred_text_field.dart';

Future<String?> scanBarcode(BuildContext context) {
  return _manualBarcodeEntry(context);
}

Future<String?> _manualBarcodeEntry(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter Barcode'),
      content: Form(
        key: formKey,
        child: CredTextField(
          controller: controller,
          label: 'Barcode',
          icon: Icons.qr_code,
          required: true,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Barcode is required' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}
