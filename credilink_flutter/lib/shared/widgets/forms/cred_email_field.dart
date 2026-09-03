import 'package:flutter/material.dart';

import '../../../core/utils/cred_validators.dart';
import 'cred_text_field.dart';

class CredEmailField extends StatelessWidget {
  const CredEmailField({
    super.key,
    required this.controller,
    this.label = 'Email',
    this.required = true,
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
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: textInputAction,
      required: required,
      validator: (v) => CredValidators.email(v, required: required),
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
