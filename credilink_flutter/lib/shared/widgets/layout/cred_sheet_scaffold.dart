import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class CredSheetScaffold extends StatelessWidget {
  const CredSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(
            child: child,
          )
        : child;

    return Padding(
      padding: EdgeInsets.only(
        left: CredTheme.spaceLg,
        right: CredTheme.spaceLg,
        top: CredTheme.spaceMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + CredTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: CredTheme.spaceMd),
              decoration: BoxDecoration(
                color: CredTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(title, style: CredTheme.pageTitle(context)),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: CredTheme.spaceMd),
          content,
        ],
      ),
    );
  }
}
