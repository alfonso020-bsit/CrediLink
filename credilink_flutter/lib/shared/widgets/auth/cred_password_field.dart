import 'package:flutter/material.dart';

import 'cred_text_field.dart';

class CredPasswordField extends StatefulWidget {
  const CredPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

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
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
      ),
    );
  }
}
