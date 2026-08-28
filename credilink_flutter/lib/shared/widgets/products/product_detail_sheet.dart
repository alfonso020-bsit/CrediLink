import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/inventory_stats.dart';
import '../../../models/product.dart';
import '../../../models/stock_transaction.dart';
import 'inventory_status_badge.dart';

class ProductDetailSheet extends StatelessWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onEdit,
    this.onAdjustStock,
    this.onDelete,
    this.transactions = const [],
    this.readOnly = false,
  });

  final Product product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onDelete;
  final List<StockTransaction> transactions;
  final bool readOnly;

  static void show(
    BuildContext context, {
    required Product product,
    VoidCallback? onAddToCart,
    VoidCallback? onEdit,
    VoidCallback? onAdjustStock,
    VoidCallback? onDelete,
    List<StockTransaction> transactions = const [],
    bool readOnly = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: ProductDetailSheet(
            product: product,
            onAddToCart: onAddToCart,
            onEdit: onEdit,
            onAdjustStock: onAdjustStock,
            onDelete: onDelete,
            transactions: transactions,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = stockStatusFor(product);
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.imageUrl!,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 64),
                ),
              ),
            ),
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(product.name, style: Theme.of(context).textTheme.titleLarge)),
              InventoryStatusBadge(product: product),
            ],
          ),
          const SizedBox(height: 12),
          if (status != StockStatus.inStock) _StockAlertCard(status: status, product: product),
          const SizedBox(height: 8),
          _DetailRow(label: 'Barcode', value: product.hasBarcode ? (product.barcode.isEmpty ? '—' : product.barcode) : 'No barcode'),
          if (!product.hasBarcode && product.customProductId != null)
            _DetailRow(label: 'Custom ID', value: product.customProductId!),
          _DetailRow(label: 'Category', value: product.category.isEmpty ? '—' : product.category),
          if (product.brand.isNotEmpty) _DetailRow(label: 'Brand', value: product.brand),
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(product.description, style: TextStyle(color: Colors.grey.shade700)),
          ],
          const Divider(height: 24),
          _DetailRow(label: 'Current Stock', value: '${product.stockQuantity} ${product.unitOfMeasure}'),
          _DetailRow(
            label: 'Stock Range',
            value: product.maxStockLevel > 0
                ? '${product.minStockLevel} – ${product.maxStockLevel} ${product.unitOfMeasure}'
                : 'Min ${product.minStockLevel} ${product.unitOfMeasure}',
          ),
          _DetailRow(label: 'Price per Unit', value: CurrencyFormatter.format(product.sellingPrice)),
          if (product.costPrice > 0) _DetailRow(label: 'Cost Price', value: CurrencyFormatter.format(product.costPrice)),
          if (product.bulkSellingPrice != null && product.piecesPerBulk != null)
            _DetailRow(
              label: 'Bulk Price',
              value: '${product.piecesPerBulk} ${product.bulkUnit ?? product.unitOfMeasure} @ ${CurrencyFormatter.format(product.bulkSellingPrice!)}',
            ),
          if (product.bulkOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Bulk Options', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...product.bulkOptions.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${b.label}: ${b.piecesPerBulk} pcs @ ${CurrencyFormatter.format(b.price)}',
                ),
              ),
            ),
          ],
          if (transactions.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Recent Stock Transactions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...transactions.take(10).map(
              (t) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  t.changeType == 'increase' ? Icons.arrow_upward : Icons.arrow_downward,
                  color: t.changeType == 'increase' ? Colors.green : Colors.red,
                  size: 18,
                ),
                title: Text('${t.previousStock} → ${t.newStock}'),
                subtitle: Text(t.reason ?? t.type),
                trailing: t.createdAt != null ? Text(dateFormat.format(t.createdAt!), style: const TextStyle(fontSize: 11)) : null,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (onAddToCart != null && !product.isOutOfStock)
            ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to Cart'),
            ),
          if (!readOnly && onEdit != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Product'),
            ),
          ],
          if (!readOnly && onAdjustStock != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAdjustStock,
              icon: const Icon(Icons.inventory_outlined),
              label: const Text('Adjust Stock'),
            ),
          ],
          if (!readOnly && onDelete != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete Product', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockAlertCard extends StatelessWidget {
  const _StockAlertCard({required this.status, required this.product});

  final StockStatus status;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final (color, message) = switch (status) {
      StockStatus.lowStock => (
          Colors.orange,
          'Low stock: ${product.stockQuantity} remaining (min ${product.minStockLevel})',
        ),
      StockStatus.outOfStock => (Colors.red, 'Out of stock — restock needed'),
      StockStatus.inStock => (Colors.green, ''),
    };

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              status == StockStatus.outOfStock ? Icons.error_outline : Icons.warning_amber,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: _darken(color)))),
          ],
        ),
      ),
    );
  }
}

Color _darken(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
