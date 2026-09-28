import 'package:credilink_flutter/models/admin_platform_snapshot.dart';
import 'package:credilink_flutter/models/user_profile.dart';
import 'package:credilink_flutter/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user({
  required String id,
  required UserRole role,
  String status = 'active',
  String? storeOwnerId,
  String? storeName,
  DateTime? createdAt,
}) {
  return UserProfile(
    id: id,
    username: id,
    fullName: id,
    role: role,
    status: status,
    province: '',
    municipality: '',
    barangay: '',
    storeOwnerId: storeOwnerId,
    storeName: storeName,
    createdAt: createdAt,
  );
}

void main() {
  final now = DateTime(2026, 9, 28, 15);

  test('one pass counts revenue, aging, today, and top stores', () {
    final snapshot = AdminPlatformSnapshot.build(
      now: now,
      users: [
        _user(id: 'owner', role: UserRole.storeOwner, storeName: 'Sari', createdAt: now),
        _user(id: 'closed', role: UserRole.storeOwner, status: 'inactive', createdAt: now),
        _user(id: 'emp', role: UserRole.employee, storeOwnerId: 'owner', createdAt: now),
        _user(id: 'cust', role: UserRole.customer, createdAt: now),
      ],
      cashSales: [
        {
          'total': 100,
          'store_owner_id': 'owner',
          'created_at': now,
        },
        {
          'total': 40,
          'store_owner_id': 'closed',
          'created_at': DateTime(2026, 9, 1),
        },
      ],
      debts: [
        {
          'remainingBalance': 6000,
          'payment_status': 'unpaid',
          'dueDate': DateTime(2026, 1, 1),
          'created_at': now,
          'payments': [
            {'paymentDate': now},
          ],
        },
      ],
    );

    expect(snapshot.platform['totalUsers'], 4);
    expect(snapshot.platform['activeStores'], 1);
    expect(snapshot.financial['totalRevenue'], 140);
    expect(snapshot.financial['totalOutstanding'], 6000);
    expect(snapshot.today['transactions'], 1);
    expect(snapshot.today['newDebts'], 1);
    expect(snapshot.today['payments'], 1);
    expect(snapshot.debtHealth['overdue90'], 6000);
    expect(snapshot.criticalAlerts, isNotEmpty);
    expect(snapshot.topStores, hasLength(1));
    expect(snapshot.topStores.first['name'], 'Sari');
    expect(snapshot.topStores.first['revenue'], 100);
    expect(snapshot.topStores.first['employeeCount'], 1);
    expect(snapshot.roles['Store Owner'], 2);
    expect(snapshot.salesTrend, hasLength(14));
    expect(snapshot.registrationTrend, hasLength(30));
    expect(snapshot.registrationTrend.last['users'], 4);
    expect(snapshot.registrationTrend.last['stores'], 2);
    expect(snapshot.registrationTrendFor(7), hasLength(7));
  });

  test('paid debts stay out of aging buckets', () {
    final snapshot = AdminPlatformSnapshot.build(
      now: now,
      users: const [],
      cashSales: const [],
      debts: [
        {
          'remainingBalance': 0,
          'payment_status': 'paid',
          'dueDate': DateTime(2026, 1, 1),
        },
      ],
    );

    expect(snapshot.debtHealth.values.every((v) => v == 0), isTrue);
    expect(snapshot.criticalAlerts, isEmpty);
  });
}
