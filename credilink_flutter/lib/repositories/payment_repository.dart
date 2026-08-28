import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/debt_record.dart';
import '../models/payment_history_entry.dart';

class PaymentRepository {
  PaymentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<DebtRecord>> getDebtsByStore(String storeOwnerId) async {
    final snap = await _firestore
        .collection('debt_products')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();
    return snap.docs.map((d) => DebtRecord.fromFirestore(d.id, d.data())).toList();
  }

  Future<List<DebtRecord>> getDebtsByCustomer(String customerId) async {
    final snap = await _firestore
        .collection('debt_products')
        .where('customer_id', isEqualTo: customerId)
        .get();
    return snap.docs.map((d) => DebtRecord.fromFirestore(d.id, d.data())).toList();
  }

  Future<List<DebtRecord>> getOverdueDebtsByStore(String storeOwnerId) async {
    final debts = await getDebtsByStore(storeOwnerId);
    return debts.where((d) => isDebtOverdue(d)).toList();
  }

  Future<List<DebtRecord>> getOverdueDebtsByCustomer(String customerId) async {
    final debts = await getDebtsByCustomer(customerId);
    return debts.where((d) => isDebtOverdue(d)).toList();
  }

  bool isDebtOverdue(DebtRecord debt) {
    if (debt.isPaid) return false;
    if (debt.status == 'overdue') return true;
    final due = debt.dueDate;
    if (due == null) return false;
    return DateTime.now().isAfter(due) && debt.remainingBalance > 0;
  }

  Future<List<PaymentHistoryEntry>> getPaymentHistory(String debtId) async {
    final snap = await _firestore
        .collection('payments')
        .where('debtProductId', isEqualTo: debtId)
        .get();

    final entries = snap.docs
        .map((d) => PaymentHistoryEntry.fromFirestore(d.id, d.data()))
        .toList();
    entries.sort((a, b) {
      final ad = a.paymentDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.paymentDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return entries;
  }

  Future<void> recordPayment({
    required String debtId,
    required double amount,
    required double currentBalance,
    String? notes,
    String? paidBy,
  }) async {
    final newBalance = currentBalance - amount;
    if (newBalance < 0) throw Exception('Payment exceeds balance');

    final debtRef = _firestore.collection('debt_products').doc(debtId);
    final debtDoc = await debtRef.get();
    final existingPayments = (debtDoc.data()?['payments'] as List?) ?? [];

    final paymentEntry = {
      'amount': amount,
      'paymentDate': FieldValue.serverTimestamp(),
      'paid_by': paidBy ?? 'User',
      'notes': ?notes,
    };

    await debtRef.update({
      'remainingBalance': newBalance,
      'payment_status': newBalance <= 0 ? 'paid' : 'partially_paid',
      'status': newBalance <= 0 ? 'paid' : 'pending',
      'payments': [...existingPayments, paymentEntry],
    });

    await _firestore.collection('payments').add({
      'debtProductId': debtId,
      'amount': amount,
      'notes': notes,
      'paid_by': paidBy ?? 'User',
      'payment_date': FieldValue.serverTimestamp(),
    });
  }

  String calculatePaymentStatus({
    required double remainingBalance,
    double initialPayment = 0,
  }) {
    if (remainingBalance <= 0) return 'paid';
    if (initialPayment > 0) return 'partially_paid';
    return 'unpaid';
  }

  bool validatePaymentAmount(double amount, double remainingBalance) {
    return amount > 0 && amount <= remainingBalance;
  }
}
