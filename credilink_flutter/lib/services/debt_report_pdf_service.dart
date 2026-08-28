import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_formatter.dart';
import '../models/debt_record.dart';

class DebtReportPdfService {
  Future<void> exportDebtReport({
    required List<DebtRecord> debts,
    required String storeName,
    required String ownerName,
  }) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final now = DateTime.now();
    final outstanding = debts.fold<double>(0, (s, d) => s + d.remainingBalance);
    final overdue = debts.where((d) => d.isOverdue && !d.isPaid).length;

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
                pw.Text('DEBT REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Store: $storeName'),
                pw.Text('Owner: $ownerName'),
                pw.Text('Generated: ${dateFormat.format(now)}'),
                pw.SizedBox(height: 8),
                pw.Text('Outstanding: ${CurrencyFormatter.format(outstanding)}'),
                pw.Text('Overdue accounts: $overdue'),
                pw.Text('Total debts: ${debts.length}'),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Customer', 'Status', 'Total', 'Remaining', 'Due'],
            data: debts.map((d) {
              return [
                d.customerName ?? d.customerId,
                d.paymentStatus,
                CurrencyFormatter.format(d.totalAmount),
                CurrencyFormatter.format(d.remainingBalance),
                d.dueDate != null ? dateFormat.format(d.dueDate!) : '—',
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
