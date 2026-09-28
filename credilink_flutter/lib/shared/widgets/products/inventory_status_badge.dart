import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/inventory_stats.dart';
import '../../../models/product.dart';

class InventoryStatusBadge extends StatelessWidget {
  const InventoryStatusBadge({super.key, required this.product, this.compact = false});

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusFor(product);
    final (label, color) = switch (status) {
      StockStatus.inStock => ('In Stock', CredTheme.success),
      StockStatus.lowStock => ('Low Stock', CredTheme.warning),
      StockStatus.outOfStock => ('Out of Stock', CredTheme.danger),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


