import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/sale_record.dart';

class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.sale,
    this.storeName,
    this.employeeName,
  });

  final SaleRecord sale;
  final String? storeName;
  final String? employeeName;

  factory ReceiptView.fromMap({
    required String id,
    required Map<String, dynamic> data,
    String? storeName,
    String? employeeName,
  }) {
    final type = (data['type'] as String?) == 'debt' ? SaleType.debt : SaleType.cash;
    final sale = type == SaleType.debt
        ? SaleRecord.fromDebtMap(id, data)
        : SaleRecord.fromCashMap(id, data);
    return ReceiptView(sale: sale, storeName: storeName, employeeName: employeeName);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy h:mm a').format(sale.createdAt!)
        : '—';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CrediLink Receipt',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              sale.type == SaleType.cash ? 'Cash Sale' : 'Debt Sale',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            if (storeName != null) _Row(label: 'Store', value: storeName!),
            if (employeeName != null) _Row(label: 'Cashier', value: employeeName!),
            if (sale.customerName != null) _Row(label: 'Customer', value: sale.customerName!),
            _Row(label: 'Receipt #', value: sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id),
            _Row(label: 'Date', value: dateStr),
            const Divider(height: 24),
            Text('Items', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sale.items.map((item) {
              final name = item['product_name'] as String? ?? 'Item';
              final qty = item['quantity'] as num? ?? 1;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                  ((item['price'] as num?)?.toDouble() ?? 0) * qty;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('$name × $qty')),
                    Text(CurrencyFormatter.format(subtotal)),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            _Row(
              label: 'Total',
              value: CurrencyFormatter.format(sale.total),
              bold: true,
            ),
            if (sale.type == SaleType.debt && sale.remainingBalance != null) ...[
              _Row(
                label: 'Remaining',
                value: CurrencyFormatter.format(sale.remainingBalance!),
              ),
              if (sale.paymentStatus != null)
                _Row(label: 'Status', value: sale.paymentStatus!),
            ],
            const SizedBox(height: 8),
            Text(
              'Thank you for your purchase!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
