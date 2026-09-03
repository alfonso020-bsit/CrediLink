import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/inventory_stats.dart';
import '../layout/cred_metric_card.dart';

class InventorySummaryCards extends StatelessWidget {
  const InventorySummaryCards({
    super.key,
    required this.stats,
    this.onLowStockTap,
    this.onOutOfStockTap,
  });

  final InventoryStats stats;
  final VoidCallback? onLowStockTap;
  final VoidCallback? onOutOfStockTap;

  @override
  Widget build(BuildContext context) {
    return CredMetricGrid(
      metrics: [
        CredMetricCard(
          label: 'Total',
          value: '${stats.total}',
          icon: Icons.inventory_2,
          accentColor: CredTheme.info,
        ),
        CredMetricCard(
          label: 'In stock',
          value: '${stats.inStock}',
          icon: Icons.check_circle_outline,
          accentColor: CredTheme.success,
        ),
        CredMetricCard(
          label: 'Low stock',
          value: '${stats.lowStock}',
          icon: Icons.warning_amber,
          accentColor: CredTheme.warning,
          onTap: stats.lowStock > 0 ? onLowStockTap : null,
        ),
        CredMetricCard(
          label: 'Out of stock',
          value: '${stats.outOfStock}',
          icon: Icons.remove_shopping_cart,
          accentColor: CredTheme.danger,
          onTap: stats.outOfStock > 0 ? onOutOfStockTap : null,
        ),
      ],
    );
  }
}
