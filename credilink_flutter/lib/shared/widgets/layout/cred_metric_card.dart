import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

enum CredMetricStyle {
  /// Compact vertical tile (icon → value → label). Default for grids.
  tile,

  /// Full-width focal metric (large value, soft accent wash).
  featured,
}

class CredMetricCard extends StatelessWidget {
  const CredMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.accentColor,
    this.onTap,
    this.style = CredMetricStyle.tile,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;
  final CredMetricStyle style;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? CredTheme.primary;
    final radius = BorderRadius.circular(CredTheme.radiusCard);

    return Material(
      color: style == CredMetricStyle.featured
          ? color.withValues(alpha: 0.08)
          : CredTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: style == CredMetricStyle.featured
              ? color.withValues(alpha: 0.22)
              : CredTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: style == CredMetricStyle.featured
            ? _FeaturedBody(
                label: label,
                value: value,
                icon: icon,
                subtitle: subtitle,
                color: color,
              )
            : _TileBody(
                label: label,
                value: value,
                icon: icon,
                subtitle: subtitle,
                color: color,
              ),
      ),
    );
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CredTheme.spaceSm,
        vertical: CredTheme.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(CredTheme.radiusInput),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          if (icon != null) const SizedBox(height: CredTheme.spaceSm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: CredTheme.metricValue(context)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CredTheme.bodyMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CredTheme.placeholder,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedBody extends StatelessWidget {
  const _FeaturedBody({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CredTheme.spaceMd),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(CredTheme.radiusInput),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: CredTheme.spaceMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CredTheme.bodyMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: CredTheme.metricValue(context).copyWith(fontSize: 28),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: CredTheme.bodyMutedStyle(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CredMetricGrid extends StatelessWidget {
  const CredMetricGrid({super.key, required this.metrics});

  final List<CredMetricCard> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - CredTheme.spaceSm) / 2;
        return Wrap(
          spacing: CredTheme.spaceSm,
          runSpacing: CredTheme.spaceSm,
          children: metrics.map((m) => SizedBox(width: width, child: m)).toList(),
        );
      },
    );
  }
}
