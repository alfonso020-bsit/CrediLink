class EmployeeProfile {
  const EmployeeProfile({
    required this.employeeId,
    required this.storeOwnerId,
    this.position,
    this.salary,
    this.hireDate,
  });

  final String employeeId;
  final String storeOwnerId;
  final String? position;
  final double? salary;
  final DateTime? hireDate;

  factory EmployeeProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return EmployeeProfile(
      employeeId: data['employee_id'] as String? ?? id,
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      position: data['position'] as String?,
      salary: (data['salary'] as num?)?.toDouble(),
      hireDate: _date(data['hire_date']),
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
