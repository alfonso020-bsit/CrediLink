import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart_item.dart';
import '../common/empty_state.dart';

class SaleCartPanel extends StatelessWidget {
  const SaleCartPanel({
    super.key,
    required this.items,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onCheckout,
    this.checkoutLabel = 'Checkout',
  });

  final List<CartItem> items;
  final void Function(int index, int quantity) onQuantityChanged;
  final void Function(int index) onRemove;
  final VoidCallback? onCheckout;
  final String checkoutLabel;

  double get _total => items.fold<double>(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        message: 'Cart is empty — add products to begin',
        icon: Icons.shopping_cart_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.product.name),
                subtitle: Text(
                  '${CurrencyFormatter.format(item.unitPrice)} × ${item.quantity}'
                  '${item.pricingOption == 'bulk' ? ' (${item.bulkOption?.label ?? 'bulk'})' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: item.quantity > 1
                          ? () => onQuantityChanged(index, item.quantity - 1)
                          : null,
                    ),
                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => onQuantityChanged(index, item.quantity + 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onRemove(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${items.length} item${items.length == 1 ? '' : 's'}'),
                  Text(
                    CurrencyFormatter.format(_total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (onCheckout != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(onPressed: onCheckout, child: Text(checkoutLabel)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
