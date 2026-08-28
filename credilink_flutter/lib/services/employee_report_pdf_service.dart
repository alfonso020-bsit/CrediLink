import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_formatter.dart';
import '../models/sale_record.dart';
import '../models/user_profile.dart';

class EmployeeReportPdfService {
  Future<void> exportEmployeeReport({
    required UserProfile employee,
    required List<SaleRecord> sales,
    DateTimeRange? dateRange,
  }) async {
    final mine = sales.where((s) => s.employeeId == employee.id).toList();
    final revenue = mine.fold<double>(0, (sum, s) => sum + s.total);
    final cashCount = mine.where((s) => s.type == SaleType.cash).length;
    final debtCount = mine.where((s) => s.type == SaleType.debt).length;
    final dateFormat = DateFormat('MMM d, yyyy');

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
                pw.Text('EMPLOYEE REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Employee: ${employee.fullName}'),
                pw.Text('Position: ${employee.position ?? 'Employee'}'),
                pw.Text('Transactions: ${mine.length}'),
                pw.Text('Revenue: ${CurrencyFormatter.format(revenue)}'),
                pw.Text('Cash: $cashCount | Debt: $debtCount'),
                if (dateRange != null)
                  pw.Text(
                    'Period: ${dateFormat.format(dateRange.start)} – ${dateFormat.format(dateRange.end.subtract(const Duration(days: 1)))}',
                  ),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Customer', 'Total'],
            data: mine.map((s) {
              return [
                s.createdAt != null ? dateFormat.format(s.createdAt!) : '—',
                s.type == SaleType.cash ? 'Cash' : 'Debt',
                s.customerName ?? 'Walk-in',
                CurrencyFormatter.format(s.total),
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
