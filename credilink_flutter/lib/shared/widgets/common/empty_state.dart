import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.action,
  });

  /// Short headline above [message]. When null, [message] is the only text.
  final String? title;
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CredTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 34,
                color: CredTheme.primary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            if (title != null && title!.trim().isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CredTheme.titleText,
                    ),
              ),
              const SizedBox(height: CredTheme.spaceXs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: CredTheme.bodyMutedStyle(context),
            ),
            if (action != null) ...[
              const SizedBox(height: CredTheme.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
