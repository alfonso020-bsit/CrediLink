import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/product.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lowStock = product.isLowStock;
    final outOfStock = product.isOutOfStock;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: outOfStock ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: product.imageUrl != null
              ? ClipOval(child: Image.network(product.imageUrl!, fit: BoxFit.cover))
              : Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: outOfStock ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.category} • Stock: ${product.stockQuantity}'),
            if (lowStock)
              const Text('Low stock', style: TextStyle(color: Colors.orange, fontSize: 12)),
            if (outOfStock)
              const Text('Out of stock', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        trailing: trailing ??
            Text(
              CurrencyFormatter.format(product.sellingPrice),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
      ),
    );
  }
}
