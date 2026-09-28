enum SaleType { cash, debt }

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.type,
    required this.total,
    required this.storeOwnerId,
    this.employeeId,
    this.customerId,
    this.customerName,
    this.status = 'completed',
    this.paymentStatus,
    this.remainingBalance,
    this.dueDate,
    this.items = const [],
    this.createdAt,
  });

  final String id;
  final SaleType type;
  final double total;
  final String storeOwnerId;
  final String? employeeId;
  final String? customerId;
  final String? customerName;
  final String status;
  final String? paymentStatus;
  final double? remainingBalance;
  final DateTime? dueDate;
  final List<Map<String, dynamic>> items;
  final DateTime? createdAt;

  bool get isPaid =>
      (paymentStatus ?? '') == 'paid' || (remainingBalance != null && remainingBalance! <= 0);

  bool get isOverdue {
    if (type != SaleType.debt || isPaid) return false;
    if (status == 'overdue') return true;
    final due = dueDate;
    if (due == null) return false;
    return DateTime.now().isAfter(due);
  }

  factory SaleRecord.fromCashMap(String id, Map<String, dynamic> data) {
    return SaleRecord(
      id: id,
      type: SaleType.cash,
      total: (data['total'] as num?)?.toDouble() ?? (data['total_amount'] as num?)?.toDouble() ?? 0,
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      employeeId: data['employee_id'] as String?,
      customerName: data['customerName'] as String?,
      status: data['status'] as String? ?? 'completed',
      items: (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      createdAt: _date(data['created_at']),
    );
  }

  factory SaleRecord.fromDebtMap(String id, Map<String, dynamic> data) {
    return SaleRecord(
      id: id,
      type: SaleType.debt,
      total: (data['total'] as num?)?.toDouble() ?? (data['total_amount'] as num?)?.toDouble() ?? 0,
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      employeeId: data['employee_id'] as String?,
      customerId: data['customer_id'] as String?,
      customerName: data['customerName'] as String? ?? data['customer_name'] as String?,
      status: data['status'] as String? ?? 'pending',
      paymentStatus: data['payment_status'] as String?,
      remainingBalance: (data['remainingBalance'] as num?)?.toDouble(),
      dueDate: _date(data['dueDate'] ?? data['due_date']),
      items: (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      createdAt: _date(data['created_at']),
    );
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    try {
      return v.toDate();
    } catch (_) {
      return v is DateTime ? v : null;
    }
  }
}
