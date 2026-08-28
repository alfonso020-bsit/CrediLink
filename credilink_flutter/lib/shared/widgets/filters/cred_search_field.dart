import 'package:flutter/material.dart';

import '../../../core/theme/auth_theme.dart';

class CredSearchField extends StatefulWidget {
  const CredSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<CredSearchField> createState() => _CredSearchFieldState();
}

class _CredSearchFieldState extends State<CredSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: Container(
        decoration: BoxDecoration(
          color: _focused ? Colors.white : AuthTheme.inputBackground,
          borderRadius: BorderRadius.circular(AuthTheme.inputRadius),
          border: Border.all(color: _focused ? primary : AuthTheme.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AuthTheme.subtitleText),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: const TextStyle(fontSize: 14, color: AuthTheme.titleText),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AuthTheme.placeholder),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  isDense: true,
                ),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged?.call('');
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }
}
