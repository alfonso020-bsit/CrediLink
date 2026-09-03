import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart_item.dart';
import '../layout/cred_sheet_scaffold.dart';

enum CheckoutType { cash, debt }

class CheckoutResult {
  const CheckoutResult({
    required this.type,
    required this.items,
  });

  final CheckoutType type;
  final List<CartItem> items;
}

/// Review cart (qty / remove), then choose Cash or Debt.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.items,
  });

  final List<CartItem> items;

  static Future<CheckoutResult?> show(
    BuildContext context, {
    required List<CartItem> items,
  }) {
    return showModalBottomSheet<CheckoutResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CheckoutSheet(items: items),
    );
  }

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  late List<CartItem> _items;
  CheckoutType _type = CheckoutType.cash;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map(_cloneItem).toList();
  }

  CartItem _cloneItem(CartItem item) {
    return CartItem(
      product: item.product,
      quantity: item.quantity,
      pricingOption: item.pricingOption,
      bulkOption: item.bulkOption,
    );
  }

  double get _total => _items.fold<double>(0, (sum, item) => sum + item.subtotal);

  void _setQuantity(int index, int quantity) {
    if (quantity < 1) return;
    setState(() => _items[index].quantity = quantity);
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return CredSheetScaffold(
      title: 'Checkout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Order summary', style: CredTheme.sectionTitle(context)),
          const SizedBox(height: CredTheme.spaceSm),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
              child: Text(
                'Cart is empty',
                textAlign: TextAlign.center,
                style: CredTheme.bodyMutedStyle(context),
              ),
            )
          else
            ...[
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                _CheckoutLine(
                  item: _items[i],
                  onQuantityChanged: (q) => _setQuantity(i, q),
                  onRemove: () => _remove(i),
                ),
              ],
            ],
          const Divider(height: CredTheme.spaceLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                CurrencyFormatter.format(_total),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: CredTheme.spaceMd),
          SegmentedButton<CheckoutType>(
            segments: const [
              ButtonSegment(
                value: CheckoutType.cash,
                label: Text('Cash'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: CheckoutType.debt,
                label: Text('Debt'),
                icon: Icon(Icons.account_balance_wallet_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: _items.isEmpty
                ? null
                : (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: CredTheme.spaceXs),
          Text(
            _type == CheckoutType.cash
                ? 'Customer pays in full now.'
                : 'Customer will be charged on account. Select or register a customer next.',
            style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 13),
          ),
          const SizedBox(height: CredTheme.spaceMd),
          ElevatedButton(
            onPressed: _items.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      CheckoutResult(type: _type, items: List<CartItem>.from(_items)),
                    ),
            child: Text(_type == CheckoutType.cash ? 'Complete Cash Sale' : 'Continue with Debt'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final void Function(int quantity) onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = item.product.imageUrl;

    return Material(
      color: CredTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        side: const BorderSide(color: CredTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CredTheme.spaceSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CredTheme.radiusInput),
              child: SizedBox(
                width: 48,
                height: 48,
                child: url != null && url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: CredTheme.primary.withValues(alpha: 0.08),
                          child: const Icon(Icons.inventory_2_outlined, size: 22),
                        ),
                      )
                    : ColoredBox(
                        color: CredTheme.primary.withValues(alpha: 0.08),
                        child: const Icon(Icons.inventory_2_outlined, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: CredTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${CurrencyFormatter.format(item.unitPrice)} × ${item.quantity}'
                    '${item.pricingOption == 'bulk' ? ' (${item.bulkOption?.label ?? 'bulk'})' : ''}',
                    style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(item.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: item.quantity > 1
                          ? () => onQuantityChanged(item.quantity - 1)
                          : null,
                    ),
                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                    ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: CredTheme.danger, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
