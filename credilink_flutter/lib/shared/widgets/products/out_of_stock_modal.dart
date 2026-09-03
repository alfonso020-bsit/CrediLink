import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/product.dart';
import 'cred_product_card.dart';

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
          padding: const EdgeInsets.all(CredTheme.spaceMd),
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
              : CredProductGrid(
                  products: products,
                  mainAxisExtent: 168,
                  padding: const EdgeInsets.fromLTRB(
                    CredTheme.spaceMd,
                    0,
                    CredTheme.spaceMd,
                    CredTheme.spaceMd,
                  ),
                  itemBuilder: (context, product, _) => CredProductCard(
                    product: product,
                    compact: true,
                    onTap: onViewProduct != null ? () => onViewProduct!(product) : null,
                    actions: [
                      if (onViewProduct != null)
                        CredProductAction(
                          label: 'View',
                          icon: Icons.visibility_outlined,
                          onSelected: () => onViewProduct!(product),
                        ),
                      if (!readOnly && onAdjustStock != null)
                        CredProductAction(
                          label: 'Adjust',
                          icon: Icons.add_box_outlined,
                          onSelected: () => onAdjustStock!(product),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
