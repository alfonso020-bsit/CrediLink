import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/product.dart';
import '../../../services/barcode_lookup_service.dart';

class BarcodeScanResultCard extends StatelessWidget {
  const BarcodeScanResultCard({
    super.key,
    required this.barcode,
    this.localProduct,
    this.lookupResult,
    required this.onView,
    required this.onAdd,
    this.onDismiss,
  });

  final String barcode;
  final Product? localProduct;
  final BarcodeLookupResult? lookupResult;
  final VoidCallback onView;
  final VoidCallback onAdd;
  final VoidCallback? onDismiss;

  bool get isFound => localProduct != null;
  bool get isExternal => lookupResult?.success == true && localProduct == null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: isFound
          ? CredTheme.success.withValues(alpha: 0.1)
          : isExternal
              ? CredTheme.primary.withValues(alpha: 0.1)
              : CredTheme.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isFound ? 'Product Found' : isExternal ? 'New Product (External)' : 'Barcode Not Found',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
              ],
            ),
            const SizedBox(height: 8),
            Text('Barcode: $barcode'),
            if (localProduct != null) ...[
              const SizedBox(height: 4),
              Text(localProduct!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Stock: ${localProduct!.stockQuantity} ${localProduct!.unitOfMeasure}'),
            ] else if (lookupResult?.product != null) ...[
              const SizedBox(height: 4),
              Text(lookupResult!.product!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (lookupResult!.product!.brand.isNotEmpty) Text('Brand: ${lookupResult!.product!.brand}'),
              if (lookupResult!.source == 'open_food_facts')
                const Chip(label: Text('Open Food Facts'), visualDensity: VisualDensity.compact),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (isFound)
                  Expanded(
                    child: ElevatedButton(onPressed: onView, child: const Text('View Product')),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
