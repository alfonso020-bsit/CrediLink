import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart_item.dart';

enum CheckoutType { cash, debt }

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.items,
  });

  final List<CartItem> items;

  static Future<CheckoutType?> show(
    BuildContext context, {
    required List<CartItem> items,
  }) {
    return showModalBottomSheet<CheckoutType>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CheckoutSheet(items: items),
    );
  }

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  CheckoutType _type = CheckoutType.cash;

  double get _total =>
      widget.items.fold<double>(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CredTheme.spaceLg,
        right: CredTheme.spaceLg,
        top: CredTheme.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + CredTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CredTheme.spaceXs),
          Text(
            'Total: ${CurrencyFormatter.format(_total)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            onSelectionChanged: (s) => setState(() => _type = s.first),
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
            onPressed: () => Navigator.pop(context, _type),
            child: Text(_type == CheckoutType.cash ? 'Complete Cash Sale' : 'Continue with Debt'),
          ),
        ],
      ),
    );
  }
}
