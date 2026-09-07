import 'package:intl/intl.dart';

import '../../models/sale_record.dart';

/// One day of aggregated sales for dashboard trend charts.
class SalesTrendPoint {
  const SalesTrendPoint({
    required this.date,
    required this.label,
    required this.revenue,
    required this.count,
  });

  final DateTime date;
  final String label;
  final double revenue;
  final int count;
}

/// Buckets [sales] into daily points for the last [days] (inclusive of today).
///
/// Missing days are filled with zero. Optional [employeeId] filters to that cashier.
List<SalesTrendPoint> buildSalesTrend({
  required List<SaleRecord> sales,
  int days = 7,
  String? employeeId,
}) {
  final dayCount = days < 1 ? 7 : days;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: dayCount - 1));

  final revenueByDay = <DateTime, double>{};
  final countByDay = <DateTime, int>{};
  for (var i = 0; i < dayCount; i++) {
    final day = start.add(Duration(days: i));
    revenueByDay[day] = 0;
    countByDay[day] = 0;
  }

  for (final sale in sales) {
    if (employeeId != null && sale.employeeId != employeeId) continue;
    final created = sale.createdAt;
    if (created == null) continue;
    final day = DateTime(created.year, created.month, created.day);
    if (day.isBefore(start) || day.isAfter(today)) continue;
    revenueByDay[day] = (revenueByDay[day] ?? 0) + sale.total;
    countByDay[day] = (countByDay[day] ?? 0) + 1;
  }

  final short = DateFormat('M/d');
  final weekday = DateFormat('E');

  return List.generate(dayCount, (i) {
    final day = start.add(Duration(days: i));
    final label = dayCount <= 7 ? weekday.format(day) : short.format(day);
    return SalesTrendPoint(
      date: day,
      label: label,
      revenue: revenueByDay[day] ?? 0,
      count: countByDay[day] ?? 0,
    );
  });
}
