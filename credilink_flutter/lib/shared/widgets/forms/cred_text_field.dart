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
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late final FocusNode _focusNode;
  bool _focused = false;

  static const Color _errorFill = Color(0xFFFEF2F2);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (focused == _focused) return;
    final leftField = _focused && !focused;
    setState(() => _focused = focused);
    // Validate when leaving the field — not on every keystroke.
    if (leftField && widget.validator != null) {
      _fieldKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final labelText = widget.required ? '${widget.label} *' : widget.label;

    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      autovalidateMode: AutovalidateMode.disabled,
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      enabled: widget.enabled,
      builder: (field) {
        final hasError = field.hasError;
        final accent = hasError ? CredTheme.danger : (_focused ? primary : CredTheme.border);
        final borderWidth = hasError || _focused ? 1.5 : 1.0;
        final fill = hasError
            ? _errorFill
            : (_focused ? Colors.white : CredTheme.inputBackground);
        final labelColor = hasError ? CredTheme.danger : CredTheme.titleText;
        final iconColor = hasError ? CredTheme.danger : CredTheme.subtitleText;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labelText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(CredTheme.radiusInput),
                border: Border.all(color: accent, width: borderWidth),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 20, color: iconColor),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      obscureText: widget.obscureText,
                      onChanged: (value) {
                        // Clear red state as soon as the user starts editing;
                        // re-check on blur or form submit.
                        if (field.hasError) {
                          field.reset();
                        }
                        field.didChange(value);
                      },
                      onSubmitted: widget.onFieldSubmitted,
                      textInputAction: widget.textInputAction,
                      autofillHints: widget.autofillHints,
                      inputFormatters: widget.inputFormatters,
                      cursorColor: hasError ? CredTheme.danger : primary,
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
                  if (widget.suffix != null)
                    IconTheme(
                      data: IconThemeData(color: iconColor),
                      child: widget.suffix!,
                    ),
                ],
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
