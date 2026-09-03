import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.autofillHints,
    this.inputFormatters,
    this.enabled = true,
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
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  State<CredTextField> createState() => _CredTextFieldState();
}

class _CredTextFieldState extends State<CredTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final labelText = widget.required ? '${widget.label} *' : widget.label;

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      enabled: widget.enabled,
      builder: (field) {
        final hasError = field.hasError;
        final borderColor = hasError
            ? CredTheme.danger
            : (_focused ? primary : CredTheme.border);

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
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 20,
                        color: hasError ? CredTheme.danger : CredTheme.subtitleText,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.enabled,
                        keyboardType: widget.keyboardType,
                        obscureText: widget.obscureText,
                        onChanged: field.didChange,
                        onSubmitted: widget.onFieldSubmitted,
                        textInputAction: widget.textInputAction,
                        autofillHints: widget.autofillHints,
                        inputFormatters: widget.inputFormatters,
                        style: const TextStyle(fontSize: 14, color: CredTheme.titleText),
                        decoration: InputDecoration(
                          hintText: widget.placeholder,
                          hintStyle: const TextStyle(color: CredTheme.placeholder),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
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
            if (hasError) ...[
              const SizedBox(height: 6),
              Text(
                field.errorText!,
                style: const TextStyle(fontSize: 12, color: CredTheme.danger),
              ),
            ],
          ],
        );
      },
    );
  }
}
