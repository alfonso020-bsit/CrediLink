import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/store_image.dart';
import '../../../models/sale_record.dart';

/// Thermal / paper-style receipt matching Ionic POS chrome.
class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.sale,
    this.storeName,
    this.storeLogoUrl,
    this.receiptHeader,
    this.receiptFooter,
    this.employeeName,
  });

  final SaleRecord sale;
  final String? storeName;
  /// HTTP URL or data-URI / base64 store logo.
  final String? storeLogoUrl;
  final String? receiptHeader;
  final String? receiptFooter;
  final String? employeeName;

  factory ReceiptView.fromMap({
    required String id,
    required Map<String, dynamic> data,
    String? storeName,
    String? storeLogoUrl,
    String? receiptHeader,
    String? receiptFooter,
    String? employeeName,
  }) {
    final type = (data['type'] as String?) == 'debt' ? SaleType.debt : SaleType.cash;
    final sale = type == SaleType.debt
        ? SaleRecord.fromDebtMap(id, data)
        : SaleRecord.fromCashMap(id, data);
    return ReceiptView(
      sale: sale,
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      employeeName: employeeName,
    );
  }

  static const _mono = TextStyle(
    fontFamily: 'Courier',
    fontSize: 12,
    height: 1.25,
    color: CredTheme.titleText,
  );

  @override
  Widget build(BuildContext context) {
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy h:mm a').format(sale.createdAt!)
        : '—';
    final receiptId = sale.id.length > 10 ? sale.id.substring(0, 10).toUpperCase() : sale.id.toUpperCase();
    final typeLabel = sale.type == SaleType.cash ? 'CASH SALE' : 'DEBT SALE';
    final title = (storeName != null && storeName!.trim().isNotEmpty) ? storeName!.trim() : 'Store';
    final header = (receiptHeader != null && receiptHeader!.trim().isNotEmpty)
        ? receiptHeader!.trim()
        : 'Retail Receipt';
    final footer = (receiptFooter != null && receiptFooter!.trim().isNotEmpty)
        ? receiptFooter!.trim()
        : 'Thank you for your purchase!';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: CredTheme.border),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: _mono,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (storeLogoUrl != null && storeLogoUrl!.trim().isNotEmpty) ...[
                  Center(child: _StoreLogo(src: storeLogoUrl!)),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _mono.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  header,
                  textAlign: TextAlign.center,
                  style: _mono.copyWith(fontSize: 11, color: CredTheme.subtitleText),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  textAlign: TextAlign.center,
                  style: _mono.copyWith(fontSize: 11, color: CredTheme.subtitleText),
                ),
                const SizedBox(height: 6),
                Text(dateStr, textAlign: TextAlign.center, style: _mono.copyWith(fontSize: 11)),
                Text('Receipt #: $receiptId', textAlign: TextAlign.center, style: _mono.copyWith(fontSize: 11)),
                const _DashedDivider(),
                if (employeeName != null && employeeName!.isNotEmpty)
                  _MetaRow(label: 'Cashier', value: employeeName!),
                if (sale.customerName != null && sale.customerName!.isNotEmpty)
                  _MetaRow(label: 'Customer', value: sale.customerName!),
                if ((employeeName != null && employeeName!.isNotEmpty) ||
                    (sale.customerName != null && sale.customerName!.isNotEmpty))
                  const _DashedDivider(),
                Text('ITEMS', style: _mono.copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
                const SizedBox(height: 8),
                if (sale.items.isEmpty)
                  Text('No line items', style: _mono.copyWith(color: CredTheme.subtitleText))
                else
                  ...sale.items.map((item) {
                    final name = item['product_name'] as String? ??
                        item['name'] as String? ??
                        'Item';
                    final qty = item['quantity'] as num? ?? 1;
                    final price = (item['price'] as num?)?.toDouble() ??
                        (item['unit_price'] as num?)?.toDouble() ??
                        0;
                    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? price * qty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: _mono.copyWith(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${qty.toString()} × ${CurrencyFormatter.format(price)}',
                                  style: _mono.copyWith(fontSize: 11, color: CredTheme.subtitleText),
                                ),
                              ),
                              Text(CurrencyFormatter.format(subtotal)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const _DashedDivider(),
                _MetaRow(
                  label: 'TOTAL',
                  value: CurrencyFormatter.format(sale.total),
                  bold: true,
                ),
                _MetaRow(
                  label: 'Payment',
                  value: sale.type == SaleType.cash ? 'CASH' : 'DEBT',
                ),
                if (sale.type == SaleType.debt) ...[
                  if (sale.remainingBalance != null)
                    _MetaRow(
                      label: 'Remaining',
                      value: CurrencyFormatter.format(sale.remainingBalance!),
                    ),
                  if (sale.paymentStatus != null)
                    _MetaRow(
                      label: 'Status',
                      value: sale.paymentStatus!.replaceAll('_', ' ').toUpperCase(),
                    ),
                ],
                const _DashedDivider(),
                Text(
                  footer,
                  textAlign: TextAlign.center,
                  style: _mono.copyWith(fontSize: 11, color: CredTheme.subtitleText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.src});

  final String src;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeStoreImageBytes(src);
    if (bytes != null) {
      return Image.memory(
        bytes,
        height: 64,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (isNetworkStoreImage(src)) {
      return Image.network(
        src,
        height: 64,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = ReceiptView._mono.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: bold ? 13 : 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: style.copyWith(
                color: bold ? CredTheme.titleText : CredTheme.subtitleText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 5.0;
          const dashSpace = 3.0;
          final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: dashWidth,
                height: 1,
                color: CredTheme.titleText.withValues(alpha: 0.45),
              ),
            ),
          );
        },
      ),
    );
  }
}
