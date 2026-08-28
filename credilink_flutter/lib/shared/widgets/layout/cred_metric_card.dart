import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class CredMetricCard extends StatelessWidget {
  const CredMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.accentColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? CredTheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CredTheme.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CredTheme.radiusInput),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: CredTheme.spaceSm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: CredTheme.bodyMutedStyle(context)),
                  const SizedBox(height: 4),
                  Text(value, style: CredTheme.metricValue(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
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
