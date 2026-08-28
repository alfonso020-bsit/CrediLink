import 'package:flutter/material.dart';

import '../../models/sale_record.dart';

bool saleMatchesDateRange(SaleRecord sale, DateTimeRange? range) {
  if (range == null || sale.createdAt == null) return true;
  final created = sale.createdAt!;
  return !created.isBefore(range.start) && created.isBefore(range.end);
}

bool saleMatchesDebtStatus(SaleRecord sale, String statusFilter) {
  if (sale.type != SaleType.debt) return true;
  if (statusFilter == 'all') return true;
  if (statusFilter == 'overdue') {
    final due = sale.createdAt?.add(const Duration(days: 30));
    final overdue = due != null && DateTime.now().isAfter(due);
    return overdue && (sale.paymentStatus ?? 'unpaid') != 'paid';
  }
  return (sale.paymentStatus ?? 'unpaid') == statusFilter;
}

List<SaleRecord> filterSales(
  List<SaleRecord> sales, {
  SaleType? type,
  DateTimeRange? dateRange,
  String debtStatus = 'all',
  String search = '',
}) {
  var result = sales;
  if (type != null) {
    result = result.where((s) => s.type == type).toList();
  }
  result = result.where((s) => saleMatchesDateRange(s, dateRange)).toList();
  if (type == SaleType.debt || type == null) {
    result = result.where((s) => saleMatchesDebtStatus(s, debtStatus)).toList();
  }
  final term = search.trim().toLowerCase();
  if (term.isNotEmpty) {
    result = result
        .where((s) =>
            (s.customerName ?? '').toLowerCase().contains(term) ||
            s.id.toLowerCase().contains(term))
        .toList();
  }
  return result;
}

double sumSalesTotal(List<SaleRecord> sales) =>
    sales.fold<double>(0, (sum, s) => sum + s.total);
