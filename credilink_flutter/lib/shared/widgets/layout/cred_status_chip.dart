import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

/// Compact status pill using CredTheme semantic colors.
class CredStatusChip extends StatelessWidget {
  const CredStatusChip({
    super.key,
    required this.label,
    this.color,
    this.compact = false,
  });

  final String label;
  final Color? color;
  final bool compact;

  factory CredStatusChip.debt({
    required String paymentStatus,
    bool isOverdue = false,
    bool compact = false,
  }) {
    if (isOverdue) {
      return CredStatusChip(label: 'Overdue', color: CredTheme.danger, compact: compact);
    }
    switch (paymentStatus) {
      case 'paid':
        return CredStatusChip(label: 'Paid', color: CredTheme.success, compact: compact);
      case 'partially_paid':
      case 'partial':
        return CredStatusChip(label: 'Partial', color: CredTheme.warning, compact: compact);
      case 'unpaid':
      case 'pending':
        return CredStatusChip(label: 'Unpaid', color: CredTheme.info, compact: compact);
      default:
        return CredStatusChip(
          label: paymentStatus.replaceAll('_', ' '),
          color: CredTheme.subtitleText,
          compact: compact,
        );
    }
  }

  factory CredStatusChip.active({required bool isActive, bool compact = false}) {
    return CredStatusChip(
      label: isActive ? 'Active' : 'Inactive',
      color: isActive ? CredTheme.success : CredTheme.subtitleText,
      compact: compact,
    );
  }

  factory CredStatusChip.saleType({required bool isCash, bool compact = false}) {
    return CredStatusChip(
      label: isCash ? 'Cash' : 'Debt',
      color: isCash ? CredTheme.success : CredTheme.info,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? CredTheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CredTheme.radiusChip),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
