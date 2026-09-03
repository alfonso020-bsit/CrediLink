import 'package:flutter/material.dart';

import '../../../core/utils/cred_validators.dart';
import 'cred_text_field.dart';

class CredPasswordField extends StatefulWidget {
  const CredPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction,
    this.newPassword = false,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final bool newPassword;
  final bool required;

  @override
  State<CredPasswordField> createState() => _CredPasswordFieldState();
}

class _CredPasswordFieldState extends State<CredPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return CredTextField(
      controller: widget.controller,
      label: widget.label,
      icon: Icons.lock_outline,
      obscureText: _obscure,
      required: widget.required,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      validator: widget.validator ??
          (widget.newPassword ? CredValidators.newPassword : CredValidators.password),
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      ),
    );
  }
}
