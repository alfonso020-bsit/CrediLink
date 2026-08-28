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

class CredQuickActionGrid extends StatelessWidget {
  const CredQuickActionGrid({
    super.key,
    required this.actions,
    this.itemWidth = 110,
  });

  final List<CredQuickAction> actions;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CredTheme.spaceXs,
      runSpacing: CredTheme.spaceXs,
      children: actions.map((action) {
        return SizedBox(
          width: itemWidth,
          child: OutlinedButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 16),
            label: Text(action.label, style: const TextStyle(fontSize: 11)),
          ),
        );
      }).toList(),
    );
  }
}
