import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart_item.dart';

/// Compact cart footer: item count, total, and checkout — no line list.
class SaleCartSummaryBar extends StatelessWidget {
  const SaleCartSummaryBar({
    super.key,
    required this.items,
    this.onCheckout,
    this.checkoutLabel = 'Checkout',
  });

  final List<CartItem> items;
  final VoidCallback? onCheckout;
  final String checkoutLabel;

  int get _itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _total => items.fold<double>(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    final empty = items.isEmpty;

    return Material(
      elevation: 8,
      color: CredTheme.cardBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CredTheme.spaceMd,
            CredTheme.spaceSm,
            CredTheme.spaceMd,
            CredTheme.spaceSm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: CredTheme.primary.withValues(alpha: 0.12),
                child: Text(
                  empty ? '0' : '$_itemCount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: empty ? CredTheme.bodyMuted : CredTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: CredTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      empty
                          ? 'Cart empty'
                          : '$_itemCount item${_itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      empty ? 'Tap products to add' : CurrencyFormatter.format(_total),
                      style: empty
                          ? CredTheme.bodyMutedStyle(context)
                          : const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CredTheme.spaceSm),
              // Theme uses Size.fromHeight (infinite min width) — override for Row.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: empty ? null : onCheckout,
                child: Text(checkoutLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
