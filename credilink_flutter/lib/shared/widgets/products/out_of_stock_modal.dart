import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/product.dart';

class OutOfStockModal extends StatelessWidget {
  const OutOfStockModal({
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
        builder: (context, scrollController) => OutOfStockModal(
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
                child: Text('Out of Stock Products', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (onFilterList != null)
                TextButton(onPressed: onFilterList, child: const Text('Filter List')),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No out of stock products'))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text(products[i].name),
                    subtitle: Text('Out of stock (min ${products[i].minStockLevel})'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(CurrencyFormatter.format(products[i].sellingPrice)),
                        if (onViewProduct != null)
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => onViewProduct!(products[i]),
                          ),
                        if (!readOnly && onAdjustStock != null)
                          IconButton(
                            icon: const Icon(Icons.add_box_outlined),
                            onPressed: () => onAdjustStock!(products[i]),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
