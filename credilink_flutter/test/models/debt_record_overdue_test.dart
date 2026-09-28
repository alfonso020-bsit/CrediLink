import 'package:credilink_flutter/models/debt_record.dart';
import 'package:flutter_test/flutter_test.dart';

DebtRecord _debt({
  String status = 'pending',
  double remaining = 100,
  DateTime? dueDate,
}) {
  return DebtRecord(
    customerId: 'c1',
    storeOwnerId: 's1',
    totalAmount: 100,
    remainingBalance: remaining,
    status: status,
    paymentStatus: remaining <= 0 ? 'paid' : 'unpaid',
    dueDate: dueDate,
  );
}

void main() {
  test('past due date is overdue even when status is pending', () {
    final debt = _debt(dueDate: DateTime.now().subtract(const Duration(days: 1)));
    expect(debt.isOverdue, isTrue);
  });

  test('future due date is not overdue', () {
    final debt = _debt(dueDate: DateTime.now().add(const Duration(days: 2)));
    expect(debt.isOverdue, isFalse);
  });

  test('explicit overdue status stays overdue', () {
    final debt = _debt(status: 'overdue', dueDate: DateTime.now().add(const Duration(days: 5)));
    expect(debt.isOverdue, isTrue);
  });

  test('paid debts are not overdue', () {
    final debt = _debt(
      status: 'overdue',
      remaining: 0,
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    expect(debt.isOverdue, isFalse);
  });
}
