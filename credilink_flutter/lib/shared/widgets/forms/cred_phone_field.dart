import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/cred_validators.dart';
import 'cred_text_field.dart';

class CredPhoneField extends StatelessWidget {
  const CredPhoneField({
    super.key,
    required this.controller,
    this.label = 'Phone',
    this.required = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return CredTextField(
      controller: controller,
      label: label,
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      textInputAction: textInputAction,
      required: required,
      placeholder: '09XX XXX XXXX',
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
        LengthLimitingTextInputFormatter(13),
      ],
      validator: (v) => CredValidators.phPhone(v, required: required),
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
