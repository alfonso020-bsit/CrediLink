import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/sale_record.dart';

class CsvExportService {
  Future<String> exportTransactions({
    required List<SaleRecord> sales,
    String filenamePrefix = 'employee-report',
  }) async {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final headers = ['Date', 'Type', 'Customer', 'Total', 'Status', 'Receipt ID'];
    final rows = sales.map((s) {
      return [
        s.createdAt != null ? dateFormat.format(s.createdAt!) : '',
        s.type == SaleType.cash ? 'Cash' : 'Debt',
        s.customerName ?? 'Walk-in',
        s.total.toStringAsFixed(2),
        s.type == SaleType.cash ? 'Paid' : (s.paymentStatus ?? ''),
        s.id,
      ];
    });

    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    final name = '$filenamePrefix-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    await Clipboard.setData(ClipboardData(text: csv));
    return name;
  }
}

class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<dynamic>> rows) {
    return rows.map((row) => row.map(_escape).join(',')).join('\n');
  }

  String _escape(dynamic value) {
    final s = '$value';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
