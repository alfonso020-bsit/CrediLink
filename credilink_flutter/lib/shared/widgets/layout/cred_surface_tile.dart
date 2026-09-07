import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

/// Bordered white/soft card row for directory and transaction lists.
class CredSurfaceTile extends StatelessWidget {
  const CredSurfaceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.emphasized = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: CredTheme.spaceMd,
      vertical: CredTheme.spaceSm,
    ),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool emphasized;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CredTheme.radiusCard);
    final borderColor = emphasized
        ? CredTheme.danger.withValues(alpha: 0.45)
        : CredTheme.border;
    final fill = emphasized
        ? CredTheme.danger.withValues(alpha: 0.1)
        : CredTheme.cardBackground;

    return Material(
      color: fill,
      elevation: emphasized ? 0 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: CredTheme.primary.withValues(alpha: 0.08),
        highlightColor: CredTheme.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: CredTheme.spaceSm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: CredTheme.titleText,
                          ),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 13),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: CredTheme.spaceSm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
