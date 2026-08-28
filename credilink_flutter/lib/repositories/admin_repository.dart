import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';
import '../models/user_profile.dart';

class AdminRepository {
  AdminRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<UserProfile>> getAllUsers() async {
    final snap = await _firestore.collection('all_users').get();
    return snap.docs.map((d) => UserProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<List<UserProfile>> getUsersByRole(String role) async {
    final snap = await _firestore
        .collection('all_users')
        .where('role', isEqualTo: role)
        .get();
    return snap.docs.map((d) => UserProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<Map<String, int>> getPlatformStats() async {
    final users = await getAllUsers();
    final storeOwners = users.where((u) => u.role.value == 'StoreOwner').toList();
    return {
      'totalUsers': users.length,
      'totalStores': storeOwners.length,
      'totalEmployees': users.where((u) => u.role.value == 'Employee').length,
      'totalCustomers': users.where((u) => u.role.value == 'Customer').length,
      'activeStores': storeOwners.where((s) => s.isActive).length,
    };
  }

  Future<Map<String, num>> getFinancialStats() async {
    try {
      final cashSnap = await _firestore.collection('cash_products').get();
      var totalRevenue = 0.0;
      final totalCashTransactions = cashSnap.docs.length;
      for (final doc in cashSnap.docs) {
        final data = doc.data();
        totalRevenue += (data['total'] as num?)?.toDouble() ??
            (data['total_amount'] as num?)?.toDouble() ??
            0;
      }

      final debtSnap = await _firestore.collection('debt_products').get();
      var totalOutstanding = 0.0;
      final totalDebtTransactions = debtSnap.docs.length;
      for (final doc in debtSnap.docs) {
        final data = doc.data();
        totalOutstanding += (data['remainingBalance'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            (data['total_amount'] as num?)?.toDouble() ??
            0;
      }

      final storeOwners = await getUsersByRole('StoreOwner');
      final activeStoreCount = storeOwners.where((s) => s.isActive).length;
      final avgStoreRevenue =
          activeStoreCount > 0 ? (totalRevenue / activeStoreCount).round() : 0;

      return {
        'totalRevenue': totalRevenue,
        'totalOutstanding': totalOutstanding,
        'avgStoreRevenue': avgStoreRevenue,
        'totalTransactions': totalCashTransactions + totalDebtTransactions,
      };
    } catch (_) {
      return {
        'totalRevenue': 0,
        'totalOutstanding': 0,
        'avgStoreRevenue': 0,
        'totalTransactions': 0,
      };
    }
  }

  Future<Map<String, int>> getTodayActivityForStore(String storeOwnerId) async {
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = start.add(const Duration(days: 1));

      var todayTransactions = 0;
      var todayNewDebts = 0;
      var todayPayments = 0;

      final cashSnap = await _firestore
          .collection('cash_products')
          .where('store_owner_id', isEqualTo: storeOwnerId)
          .get();
      for (final doc in cashSnap.docs) {
        final created = _toDate(doc.data()['created_at']);
        if (created != null && !created.isBefore(start) && created.isBefore(end)) {
          todayTransactions++;
        }
      }

      final debtSnap = await _firestore
          .collection('debt_products')
          .where('store_owner_id', isEqualTo: storeOwnerId)
          .get();
      for (final doc in debtSnap.docs) {
        final data = doc.data();
        final created = _toDate(data['created_at']);
        if (created != null && !created.isBefore(start) && created.isBefore(end)) {
          todayNewDebts++;
        }

        final payments = data['payments'] as List? ?? [];
        for (final payment in payments) {
          if (payment is! Map) continue;
          final paymentDate = _toDate(payment['paymentDate'] ?? payment['payment_date']);
          if (paymentDate != null &&
              !paymentDate.isBefore(start) &&
              paymentDate.isBefore(end)) {
            todayPayments++;
          }
        }
      }

      return {
        'transactions': todayTransactions,
        'newDebts': todayNewDebts,
        'payments': todayPayments,
      };
    } catch (_) {
      return {'transactions': 0, 'newDebts': 0, 'payments': 0};
    }
  }

  Future<Map<String, int>> getTodayActivity() async {
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = start.add(const Duration(days: 1));

      var todayTransactions = 0;
      var todayNewDebts = 0;
      var todayPayments = 0;

      final cashSnap = await _firestore.collection('cash_products').get();
      for (final doc in cashSnap.docs) {
        final created = _toDate(doc.data()['created_at']);
        if (created != null && !created.isBefore(start) && created.isBefore(end)) {
          todayTransactions++;
        }
      }

      final debtSnap = await _firestore.collection('debt_products').get();
      for (final doc in debtSnap.docs) {
        final data = doc.data();
        final created = _toDate(data['created_at']);
        if (created != null && !created.isBefore(start) && created.isBefore(end)) {
          todayNewDebts++;
        }

        final payments = data['payments'] as List? ?? [];
        for (final payment in payments) {
          if (payment is! Map) continue;
          final paymentDate = _toDate(payment['paymentDate'] ?? payment['payment_date']);
          if (paymentDate != null &&
              !paymentDate.isBefore(start) &&
              paymentDate.isBefore(end)) {
            todayPayments++;
          }
        }
      }

      return {
        'transactions': todayTransactions,
        'newDebts': todayNewDebts,
        'payments': todayPayments,
      };
    } catch (_) {
      return {'transactions': 0, 'newDebts': 0, 'payments': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getTopStores({int limit = 5}) async {
    try {
      final storeOwners = await getUsersByRole('StoreOwner');
      final employees = await getUsersByRole('Employee');
      final performance = <Map<String, dynamic>>[];

      for (final store in storeOwners) {
        if (!store.isActive) continue;

        final cashSnap = await _firestore
            .collection('cash_products')
            .where('store_owner_id', isEqualTo: store.id)
            .get();

        var storeRevenue = 0.0;
        for (final doc in cashSnap.docs) {
          storeRevenue += (doc.data()['total'] as num?)?.toDouble() ?? 0;
        }

        final storeEmployees =
            employees.where((e) => e.storeOwnerId == store.id).length;

        performance.add({
          'id': store.id,
          'name': store.storeName ?? store.fullName,
          'revenue': storeRevenue.round(),
          'employeeCount': storeEmployees,
          'status': store.status,
        });
      }

      performance.sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));
      return performance.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCriticalAlerts() async {
    try {
      final alerts = <Map<String, dynamic>>[];
      final debtHealth = await getDebtHealth();
      final totalOverdue90 = debtHealth['overdue90'] ?? 0;

      if (totalOverdue90 > 5000) {
        alerts.add({
          'icon': 'warning',
          'color': 'danger',
          'message':
              'High overdue debt: ${totalOverdue90.toStringAsFixed(0)} PHP in 90+ days category',
          'type': 'high_overdue',
        });
      }

      return alerts;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, double>> getDebtHealth() async {
    try {
      final debtSnap = await _firestore.collection('debt_products').get();
      final now = DateTime.now();
      final health = {
        'current': 0.0,
        'overdue30': 0.0,
        'overdue60': 0.0,
        'overdue90': 0.0,
      };

      for (final doc in debtSnap.docs) {
        final data = doc.data();
        if (data['payment_status'] == 'paid') continue;

        final dueDate = _toDate(data['dueDate'] ?? data['due_date']);
        if (dueDate == null) continue;

        final remaining = (data['remainingBalance'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            0;
        final daysOverdue = now.difference(dueDate).inDays;

        if (daysOverdue <= 0) {
          health['current'] = health['current']! + remaining;
        } else if (daysOverdue <= 30) {
          health['overdue30'] = health['overdue30']! + remaining;
        } else if (daysOverdue <= 60) {
          health['overdue60'] = health['overdue60']! + remaining;
        } else {
          health['overdue90'] = health['overdue90']! + remaining;
        }
      }

      return health;
    } catch (_) {
      return {'current': 0, 'overdue30': 0, 'overdue60': 0, 'overdue90': 0};
    }
  }

  Future<List<StoreProfile>> getAllStores() async {
    final snap = await _firestore.collection('store_profiles').get();
    return snap.docs.map((d) => StoreProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<Map<String, int>> getRoleDistribution() async {
    final users = await getAllUsers();
    return {
      'Admin': users.where((u) => u.role.value == 'Admin').length,
      'Store Owner': users.where((u) => u.role.value == 'StoreOwner').length,
      'Employee': users.where((u) => u.role.value == 'Employee').length,
      'Customer': users.where((u) => u.role.value == 'Customer').length,
    };
  }

  Future<List<Map<String, dynamic>>> getRegistrationTrend({int days = 7}) async {
    final users = await getAllUsers();
    final today = DateTime.now();
    final trend = <String, Map<String, dynamic>>{};

    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final key = _dateKey(date);
      trend[key] = {
        'date': date,
        'label': _trendLabel(date),
        'users': 0,
        'stores': 0,
      };
    }

    for (final user in users) {
      final created = user.createdAt;
      if (created == null) continue;
      final key = _dateKey(DateTime(created.year, created.month, created.day));
      final bucket = trend[key];
      if (bucket == null) continue;
      bucket['users'] = (bucket['users'] as int) + 1;
      if (user.role.value == 'StoreOwner') {
        bucket['stores'] = (bucket['stores'] as int) + 1;
      }
    }

    return trend.values.toList();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _trendLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
}
