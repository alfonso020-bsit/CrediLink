import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class CredQuickAction {
  const CredQuickAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

/// Equal-width soft icon tiles in a wrap (up to 4 columns).
class CredQuickActionGrid extends StatelessWidget {
  const CredQuickActionGrid({
    super.key,
    required this.actions,
    this.maxColumns = 4,
  });

  final List<CredQuickAction> actions;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = actions.length < maxColumns ? actions.length : maxColumns;
        if (cols == 0) return const SizedBox.shrink();
        final gap = CredTheme.spaceSm;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions.map((action) {
            return SizedBox(
              width: width,
              child: _QuickActionTile(action: action),
            );
          }).toList(),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final CredQuickAction action;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CredTheme.radiusCard);

    return Material(
      color: CredTheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: CredTheme.primary.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: CredTheme.spaceMd,
            horizontal: CredTheme.spaceXs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: CredTheme.primary, size: 22),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CredTheme.titleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
