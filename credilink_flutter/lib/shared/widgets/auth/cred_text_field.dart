import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class CredTextField extends StatefulWidget {
  const CredTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
    this.onFieldSubmitted,
    this.textInputAction,
    this.placeholder,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final String? placeholder;
  final bool required;

  @override
  State<CredTextField> createState() => _CredTextFieldState();
}

class _CredTextFieldState extends State<CredTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final labelText = widget.required ? '${widget.label} *' : widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CredTheme.titleText,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: Container(
            decoration: BoxDecoration(
              color: _focused ? Colors.white : CredTheme.inputBackground,
              borderRadius: BorderRadius.circular(CredTheme.radiusInput),
              border: Border.all(
                color: _focused ? primary : CredTheme.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: CredTheme.subtitleText),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    keyboardType: widget.keyboardType,
                    obscureText: widget.obscureText,
                    validator: widget.validator,
                    onFieldSubmitted: widget.onFieldSubmitted,
                    textInputAction: widget.textInputAction,
                    style: const TextStyle(fontSize: 14, color: CredTheme.titleText),
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: const TextStyle(color: CredTheme.placeholder),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      isDense: true,
                    ),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
