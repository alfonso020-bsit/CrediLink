import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/product.dart';
import 'inventory_status_badge.dart';

class InventoryProductListTile extends StatelessWidget {
  const InventoryProductListTile({
    super.key,
    required this.product,
    this.onTap,
    this.onView,
    this.onEdit,
    this.onAdjustStock,
    this.onDelete,
    this.showBrand = true,
    this.showRowActions = false,
    this.enableSlideActions = false,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onDelete;
  final bool showBrand;
  final bool showRowActions;
  final bool enableSlideActions;

  String get _bulkLine {
    if (product.bulkOptions.isNotEmpty) {
      final first = product.bulkOptions.first;
      return 'Bulk: ${first.piecesPerBulk} ${product.unitOfMeasure} @ ${CurrencyFormatter.format(first.price)}';
    }
    if (product.bulkSellingPrice != null && product.piecesPerBulk != null) {
      return 'Bulk: ${product.piecesPerBulk} ${product.bulkUnit ?? product.unitOfMeasure} @ ${CurrencyFormatter.format(product.bulkSellingPrice!)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: _ProductAvatar(product: product),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock: ${product.stockQuantity} ${product.unitOfMeasure} | Price: ${CurrencyFormatter.format(product.sellingPrice)}',
            ),
            if (showBrand && (product.category.isNotEmpty || product.brand.isNotEmpty))
              Text(
                [
                  if (product.category.isNotEmpty) product.category,
                  if (product.brand.isNotEmpty) product.brand,
                ].join(' • '),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            if (_bulkLine.isNotEmpty)
              Text(_bulkLine, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showRowActions) ...[
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: onView ?? onTap,
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
            ],
            InventoryStatusBadge(product: product, compact: true),
            if (onTap != null && !showRowActions) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        isThreeLine: true,
      ),
    );

    if (!enableSlideActions) return tile;

    return Dismissible(
      key: ValueKey(product.id ?? product.barcode),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onAdjustStock?.call();
          return false;
        }
        if (direction == DismissDirection.endToStart && onDelete != null) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Product'),
              content: Text('Deactivate "${product.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ),
          );
          if (confirmed == true) onDelete?.call();
        }
        return false;
      },
      background: Container(
        color: Colors.blue.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.inventory_outlined, color: Colors.blue),
      ),
      secondaryBackground: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: tile,
    );
  }
}

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: url != null && url.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2),
              ),
            )
          : Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
    );
  }
}
