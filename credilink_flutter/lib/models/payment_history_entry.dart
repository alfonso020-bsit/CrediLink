class PaymentHistoryEntry {
  const PaymentHistoryEntry({
    required this.id,
    required this.debtId,
    required this.amount,
    this.paidBy,
    this.notes,
    this.paymentDate,
  });

  final String id;
  final String debtId;
  final double amount;
  final String? paidBy;
  final String? notes;
  final DateTime? paymentDate;

  factory PaymentHistoryEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return PaymentHistoryEntry(
      id: id,
      debtId: data['debtProductId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paidBy: data['paid_by'] as String?,
      notes: data['notes'] as String?,
      paymentDate: _date(data['payment_date']),
    );
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    try {
      return v.toDate();
    } catch (_) {
      return null;
    }
  }
}
