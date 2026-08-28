import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon, this.action});

  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CredTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 48,
              color: CredTheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CredTheme.bodyMutedStyle(context),
            ),
            if (action != null) ...[
              const SizedBox(height: CredTheme.spaceSm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
