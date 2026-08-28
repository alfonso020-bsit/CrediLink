import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/sale_record.dart';

class PdfExportButton extends StatelessWidget {
  const PdfExportButton({
    super.key,
    required this.sale,
    this.storeName,
    this.employeeName,
    this.label = 'Export PDF',
  });

  final SaleRecord sale;
  final String? storeName;
  final String? employeeName;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _export(context),
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: Text(label),
    );
  }

  Future<void> _export(BuildContext context) async {
    final doc = _buildDocument();
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Document _buildDocument() {
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy h:mm a').format(sale.createdAt!)
        : '—';
    final typeLabel = sale.type == SaleType.cash ? 'Cash Sale' : 'Debt Sale';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'CrediLink Receipt',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(typeLabel)),
            pw.Divider(),
            if (storeName != null) _pdfRow('Store', storeName!),
            if (employeeName != null) _pdfRow('Cashier', employeeName!),
            if (sale.customerName != null) _pdfRow('Customer', sale.customerName!),
            _pdfRow('Receipt #', sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id),
            _pdfRow('Date', dateStr),
            pw.Divider(),
            pw.Text('Items', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...sale.items.map((item) {
              final name = item['product_name'] as String? ?? 'Item';
              final qty = item['quantity'] as num? ?? 1;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                  ((item['price'] as num?)?.toDouble() ?? 0) * qty;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('$name × $qty')),
                    pw.Text(CurrencyFormatter.format(subtotal)),
                  ],
                ),
              );
            }),
            pw.Divider(),
            _pdfRow('Total', CurrencyFormatter.format(sale.total), bold: true),
            if (sale.type == SaleType.debt && sale.remainingBalance != null)
              _pdfRow('Remaining', CurrencyFormatter.format(sale.remainingBalance!)),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Thank you for your purchase!',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
