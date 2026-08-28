import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:credilink_flutter/core/utils/sale_filters.dart';
import 'package:credilink_flutter/models/sale_record.dart';

void main() {
  test('filterSales by type and date range', () {
    final now = DateTime(2026, 1, 15);
    final sales = [
      SaleRecord(
        id: '1',
        type: SaleType.cash,
        total: 100,
        storeOwnerId: 's1',
        createdAt: now,
      ),
      SaleRecord(
        id: '2',
        type: SaleType.debt,
        total: 200,
        storeOwnerId: 's1',
        paymentStatus: 'unpaid',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];

    final cashOnly = filterSales(sales, type: SaleType.cash);
    expect(cashOnly.length, 1);
    expect(cashOnly.first.id, '1');

    final range = DateTimeRange(
      start: DateTime(2026, 1, 14),
      end: DateTime(2026, 1, 16),
    );
    final inRange = filterSales(sales, dateRange: range);
    expect(inRange.length, 1);
  });
}
