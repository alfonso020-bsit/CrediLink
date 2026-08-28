class DebtRecord {
  const DebtRecord({
    this.id,
    required this.customerId,
    required this.storeOwnerId,
    required this.totalAmount,
    required this.remainingBalance,
    required this.status,
    required this.paymentStatus,
    this.customerName,
    this.customerPhone,
    this.employeeId,
    this.items = const [],
    this.dueDate,
    this.createdAt,
  });

  final String? id;
  final String customerId;
  final String storeOwnerId;
  final double totalAmount;
  final double remainingBalance;
  final String status;
  final String paymentStatus;
  final String? customerName;
  final String? customerPhone;
  final String? employeeId;
  final List<Map<String, dynamic>> items;
  final DateTime? dueDate;
  final DateTime? createdAt;

  bool get isOverdue => status == 'overdue';
  bool get isPaid => remainingBalance <= 0;

  factory DebtRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return DebtRecord(
      id: id,
      customerId: data['customer_id'] as String? ?? '',
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? (data['total'] as num?)?.toDouble() ?? 0,
      remainingBalance: (data['remainingBalance'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'pending',
      paymentStatus: data['payment_status'] as String? ?? 'unpaid',
      customerName: data['customer_name'] as String? ?? data['customerName'] as String?,
      customerPhone: data['customerPhone'] as String?,
      employeeId: data['employee_id'] as String?,
      items: (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      dueDate: _toDate(data['dueDate'] ?? data['due_date']),
      createdAt: _toDate(data['created_at']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
}
