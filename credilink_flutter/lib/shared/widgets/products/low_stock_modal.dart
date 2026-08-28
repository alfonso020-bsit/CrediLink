import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/product.dart';

class LowStockModal extends StatelessWidget {
  const LowStockModal({
    super.key,
    required this.products,
    this.onViewProduct,
    this.onAdjustStock,
    this.onFilterList,
    this.readOnly = false,
  });

  final List<Product> products;
  final void Function(Product product)? onViewProduct;
  final void Function(Product product)? onAdjustStock;
  final VoidCallback? onFilterList;
  final bool readOnly;

  static Future<void> show(
    BuildContext context, {
    required List<Product> products,
    void Function(Product product)? onViewProduct,
    void Function(Product product)? onAdjustStock,
    VoidCallback? onFilterList,
    bool readOnly = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => LowStockModal(
          products: products,
          onViewProduct: onViewProduct,
          onAdjustStock: onAdjustStock,
          onFilterList: onFilterList,
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Low Stock Products', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (onFilterList != null)
                TextButton(onPressed: onFilterList, child: const Text('Filter List')),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No low stock products'))
              : ListView.builder(
                  controller: PrimaryScrollController.of(context),
                  itemCount: products.length,
                  itemBuilder: (_, i) => _AlertProductTile(
                    product: products[i],
                    onView: onViewProduct != null ? () => onViewProduct!(products[i]) : null,
                    onAdjust: !readOnly && onAdjustStock != null
                        ? () => onAdjustStock!(products[i])
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

class _AlertProductTile extends StatelessWidget {
  const _AlertProductTile({required this.product, this.onView, this.onAdjust});

  final Product product;
  final VoidCallback? onView;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber, color: Colors.orange),
      title: Text(product.name),
      subtitle: Text(
        'Stock ${product.stockQuantity} ${product.unitOfMeasure} / min ${product.minStockLevel}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(CurrencyFormatter.format(product.sellingPrice)),
          if (onView != null)
            IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: onView),
          if (onAdjust != null)
            IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: onAdjust),
        ],
      ),
    );
  }
}
