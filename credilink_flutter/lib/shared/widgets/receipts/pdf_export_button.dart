import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/store_image.dart';
import '../../../models/sale_record.dart';

class PdfExportButton extends StatelessWidget {
  const PdfExportButton({
    super.key,
    required this.sale,
    this.storeName,
    this.storeLogoUrl,
    this.receiptHeader,
    this.receiptFooter,
    this.employeeName,
    this.label = 'Export PDF',
  });

  final SaleRecord sale;
  final String? storeName;
  final String? storeLogoUrl;
  final String? receiptHeader;
  final String? receiptFooter;
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
    final doc = await _buildDocument();
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<pw.Document> _buildDocument() async {
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy h:mm a').format(sale.createdAt!)
        : '—';
    final typeLabel = sale.type == SaleType.cash ? 'CASH SALE' : 'DEBT SALE';
    final title = (storeName != null && storeName!.trim().isNotEmpty)
        ? storeName!.trim()
        : 'Store';
    final header = (receiptHeader != null && receiptHeader!.trim().isNotEmpty)
        ? receiptHeader!.trim()
        : 'Retail Receipt';
    final footer = (receiptFooter != null && receiptFooter!.trim().isNotEmpty)
        ? receiptFooter!.trim()
        : 'Thank you for your purchase!';
    final receiptId =
        sale.id.length > 10 ? sale.id.substring(0, 10).toUpperCase() : sale.id.toUpperCase();

    pw.ImageProvider? logoImage;
    final bytes = decodeStoreImageBytes(storeLogoUrl);
    if (bytes != null) {
      logoImage = pw.MemoryImage(bytes);
    } else if (isNetworkStoreImage(storeLogoUrl)) {
      try {
        logoImage = await networkImage(storeLogoUrl!);
      } catch (_) {
        logoImage = null;
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logoImage != null) ...[
              pw.Center(
                child: pw.Image(logoImage, height: 48, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 6),
            ],
            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(header, style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(typeLabel, style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9))),
            pw.Center(child: pw.Text('Receipt #: $receiptId', style: const pw.TextStyle(fontSize: 9))),
            pw.Divider(),
            if (employeeName != null) _pdfRow('Cashier', employeeName!),
            if (sale.customerName != null) _pdfRow('Customer', sale.customerName!),
            if (employeeName != null || sale.customerName != null) pw.Divider(),
            pw.Text('ITEMS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...sale.items.map((item) {
              final name = item['product_name'] as String? ?? item['name'] as String? ?? 'Item';
              final qty = item['quantity'] as num? ?? 1;
              final price = (item['price'] as num?)?.toDouble() ??
                  (item['unit_price'] as num?)?.toDouble() ??
                  0;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ?? price * qty;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${qty.toString()} x ${CurrencyFormatter.format(price)}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(CurrencyFormatter.format(subtotal), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            pw.Divider(),
            _pdfRow('TOTAL', CurrencyFormatter.format(sale.total), bold: true),
            _pdfRow('Payment', sale.type == SaleType.cash ? 'CASH' : 'DEBT'),
            if (sale.type == SaleType.debt && sale.remainingBalance != null)
              _pdfRow('Remaining', CurrencyFormatter.format(sale.remainingBalance!)),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(footer, style: const pw.TextStyle(fontSize: 9)),
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
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
