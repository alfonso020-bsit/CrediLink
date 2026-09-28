import 'user_profile.dart';
import 'user_role.dart';

/// Platform totals derived from one read of users, cash sales, and debts.
class AdminPlatformSnapshot {
  const AdminPlatformSnapshot({
    required this.loadedAt,
    required this.platform,
    required this.financial,
    required this.today,
    required this.debtHealth,
    required this.topStores,
    required this.criticalAlerts,
    required this.roles,
    required this.salesTrend,
    required this.registrationTrend,
  });

  final DateTime loadedAt;
  final Map<String, int> platform;
  final Map<String, num> financial;
  final Map<String, int> today;
  final Map<String, double> debtHealth;
  final List<Map<String, dynamic>> topStores;
  final List<Map<String, dynamic>> criticalAlerts;
  final Map<String, int> roles;
  final List<Map<String, dynamic>> salesTrend;
  final List<Map<String, dynamic>> registrationTrend;

  List<Map<String, dynamic>> registrationTrendFor(int days) {
    if (days >= registrationTrend.length) return registrationTrend;
    if (days <= 0) return const [];
    return registrationTrend.sublist(registrationTrend.length - days);
  }

  factory AdminPlatformSnapshot.build({
    required List<UserProfile> users,
    required List<Map<String, dynamic>> cashSales,
    required List<Map<String, dynamic>> debts,
    DateTime? now,
    int salesTrendDays = 14,
    int registrationTrendDays = 30,
    int topStoreLimit = 6,
  }) {
    final clock = now ?? DateTime.now();
    final todayStart = DateTime(clock.year, clock.month, clock.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final storeOwners = users.where((u) => u.role == UserRole.storeOwner).toList();
    final activeOwners = storeOwners.where((u) => u.isActive).toList();
    final employees = users.where((u) => u.role == UserRole.employee).toList();

    final platform = <String, int>{
      'totalUsers': users.length,
      'totalStores': storeOwners.length,
      'totalEmployees': employees.length,
      'totalCustomers': users.where((u) => u.role == UserRole.customer).length,
      'activeStores': activeOwners.length,
    };

    final roles = <String, int>{
      'Admin': users.where((u) => u.role == UserRole.admin).length,
      'Store Owner': storeOwners.length,
      'Employee': employees.length,
      'Customer': platform['totalCustomers']!,
    };

    var totalRevenue = 0.0;
    final revenueByStore = <String, double>{};
    var todayTransactions = 0;
    final salesTrend = _emptyTrend(
      todayStart,
      salesTrendDays,
      extras: const {'revenue': 0.0, 'transactions': 0},
    );
    final salesStart = todayStart.subtract(Duration(days: salesTrendDays - 1));

    for (final sale in cashSales) {
      final amount = (sale['total'] as num?)?.toDouble() ??
          (sale['total_amount'] as num?)?.toDouble() ??
          0;
      totalRevenue += amount;

      final storeId = sale['store_owner_id'] as String?;
      if (storeId != null && storeId.isNotEmpty) {
        revenueByStore[storeId] = (revenueByStore[storeId] ?? 0) +
            ((sale['total'] as num?)?.toDouble() ?? 0);
      }

      final created = _toDate(sale['created_at']);
      if (created == null) continue;
      if (!created.isBefore(todayStart) && created.isBefore(todayEnd)) {
        todayTransactions++;
      }
      if (created.isBefore(salesStart)) continue;
      final bucket = salesTrend[_dateKey(DateTime(created.year, created.month, created.day))];
      if (bucket == null) continue;
      bucket['revenue'] = (bucket['revenue'] as double) + amount;
      bucket['transactions'] = (bucket['transactions'] as int) + 1;
    }

    var totalOutstanding = 0.0;
    var todayNewDebts = 0;
    var todayPayments = 0;
    final debtHealth = <String, double>{
      'current': 0,
      'overdue30': 0,
      'overdue60': 0,
      'overdue90': 0,
    };

    for (final debt in debts) {
      totalOutstanding += (debt['remainingBalance'] as num?)?.toDouble() ??
          (debt['total'] as num?)?.toDouble() ??
          (debt['total_amount'] as num?)?.toDouble() ??
          0;

      final created = _toDate(debt['created_at']);
      if (created != null && !created.isBefore(todayStart) && created.isBefore(todayEnd)) {
        todayNewDebts++;
      }

      final payments = debt['payments'] as List? ?? const [];
      for (final payment in payments) {
        if (payment is! Map) continue;
        final paymentDate = _toDate(payment['paymentDate'] ?? payment['payment_date']);
        if (paymentDate != null &&
            !paymentDate.isBefore(todayStart) &&
            paymentDate.isBefore(todayEnd)) {
          todayPayments++;
        }
      }

      if (debt['payment_status'] == 'paid') continue;
      final dueDate = _toDate(debt['dueDate'] ?? debt['due_date']);
      if (dueDate == null) continue;
      final remaining = (debt['remainingBalance'] as num?)?.toDouble() ??
          (debt['total'] as num?)?.toDouble() ??
          0;
      final daysOverdue = clock.difference(dueDate).inDays;
      if (daysOverdue <= 0) {
        debtHealth['current'] = debtHealth['current']! + remaining;
      } else if (daysOverdue <= 30) {
        debtHealth['overdue30'] = debtHealth['overdue30']! + remaining;
      } else if (daysOverdue <= 60) {
        debtHealth['overdue60'] = debtHealth['overdue60']! + remaining;
      } else {
        debtHealth['overdue90'] = debtHealth['overdue90']! + remaining;
      }
    }

    final activeStoreCount = activeOwners.length;
    final financial = <String, num>{
      'totalRevenue': totalRevenue,
      'totalOutstanding': totalOutstanding,
      'avgStoreRevenue':
          activeStoreCount > 0 ? (totalRevenue / activeStoreCount).round() : 0,
      'totalTransactions': cashSales.length + debts.length,
    };

    final topStores = <Map<String, dynamic>>[
      for (final store in activeOwners)
        {
          'id': store.id,
          'name': store.storeName ?? store.fullName,
          'revenue': (revenueByStore[store.id] ?? 0).round(),
          'employeeCount': employees.where((e) => e.storeOwnerId == store.id).length,
          'status': store.status,
        },
    ]..sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));

    final overdue90 = debtHealth['overdue90'] ?? 0;
    final criticalAlerts = <Map<String, dynamic>>[
      if (overdue90 > 5000)
        {
          'icon': 'warning',
          'color': 'danger',
          'message':
              'High overdue debt: ${overdue90.toStringAsFixed(0)} PHP in 90+ days category',
          'type': 'high_overdue',
        },
    ];

    final registration = _emptyTrend(todayStart, registrationTrendDays, extras: const {
      'users': 0,
      'stores': 0,
    });
    for (final user in users) {
      final created = user.createdAt;
      if (created == null) continue;
      final bucket = registration[_dateKey(DateTime(created.year, created.month, created.day))];
      if (bucket == null) continue;
      bucket['users'] = (bucket['users'] as int) + 1;
      if (user.role == UserRole.storeOwner) {
        bucket['stores'] = (bucket['stores'] as int) + 1;
      }
    }

    return AdminPlatformSnapshot(
      loadedAt: clock,
      platform: platform,
      financial: financial,
      today: {
        'transactions': todayTransactions,
        'newDebts': todayNewDebts,
        'payments': todayPayments,
      },
      debtHealth: debtHealth,
      topStores: topStores.take(topStoreLimit).toList(),
      criticalAlerts: criticalAlerts,
      roles: roles,
      salesTrend: salesTrend.values.toList(),
      registrationTrend: registration.values.toList(),
    );
  }
}

Map<String, Map<String, dynamic>> _emptyTrend(
  DateTime todayStart,
  int days, {
  required Map<String, Object> extras,
}) {
  final trend = <String, Map<String, dynamic>>{};
  for (var i = days - 1; i >= 0; i--) {
    final date = todayStart.subtract(Duration(days: i));
    trend[_dateKey(date)] = {
      'date': date,
      'label': _trendLabel(date),
      ...extras,
    };
  }
  return trend;
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _trendLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
