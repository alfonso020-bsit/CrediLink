import 'package:flutter/material.dart';

import '../../../core/utils/inventory_stats.dart';
import '../common/stat_card.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Total',
                  value: '${stats.total}',
                  icon: Icons.inventory_2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'In Stock',
                  value: '${stats.inStock}',
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: stats.lowStock > 0 ? onLowStockTap : null,
                  borderRadius: BorderRadius.circular(12),
                  child: StatCard(
                    label: 'Low Stock',
                    value: '${stats.lowStock}',
                    icon: Icons.warning_amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: stats.outOfStock > 0 ? onOutOfStockTap : null,
                  borderRadius: BorderRadius.circular(12),
                  child: StatCard(
                    label: 'Out of Stock',
                    value: '${stats.outOfStock}',
                    icon: Icons.remove_shopping_cart,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
