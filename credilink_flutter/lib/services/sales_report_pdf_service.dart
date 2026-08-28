import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_formatter.dart';
import '../core/utils/sale_filters.dart';
import '../models/sale_record.dart';

class SalesReportPdfService {
  Future<void> exportSalesReport({
    required List<SaleRecord> sales,
    required String storeName,
    required String ownerName,
    DateTimeRange? dateRange,
    SaleType? typeFilter,
  }) async {
    final filtered = filterSales(
      sales,
      type: typeFilter,
      dateRange: dateRange,
    );
    final cash = filtered.where((s) => s.type == SaleType.cash).toList();
    final debt = filtered.where((s) => s.type == SaleType.debt).toList();
    final dateFormat = DateFormat('MMM d, yyyy');
    final now = DateTime.now();

    String periodLabel = 'All time';
    if (dateRange != null) {
      periodLabel =
          '${dateFormat.format(dateRange.start)} – ${dateFormat.format(dateRange.end.subtract(const Duration(days: 1)))}';
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SALES REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Store: $storeName'),
                pw.Text('Owner: $ownerName'),
                pw.Text('Period: $periodLabel'),
                pw.Text('Generated: ${dateFormat.format(now)}'),
                pw.SizedBox(height: 8),
                pw.Text('Total Revenue: ${CurrencyFormatter.format(sumSalesTotal(filtered))}'),
                pw.Text('Cash: ${cash.length} txns (${CurrencyFormatter.format(sumSalesTotal(cash))})'),
                pw.Text('Debt: ${debt.length} txns (${CurrencyFormatter.format(sumSalesTotal(debt))})'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Customer', 'Total', 'Status'],
            data: filtered.map((s) {
              final date = s.createdAt != null ? dateFormat.format(s.createdAt!) : '—';
              return [
                date,
                s.type == SaleType.cash ? 'Cash' : 'Debt',
                s.customerName ?? 'Walk-in',
                CurrencyFormatter.format(s.total),
                s.type == SaleType.cash ? 'Paid' : (s.paymentStatus ?? '—'),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
