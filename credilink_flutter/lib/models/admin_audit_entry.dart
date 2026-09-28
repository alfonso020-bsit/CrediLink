class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.targetId,
    required this.targetName,
    required this.targetKind,
    required this.oldStatus,
    required this.newStatus,
    this.createdAt,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String targetId;
  final String targetName;
  final String targetKind;
  final String oldStatus;
  final String newStatus;
  final DateTime? createdAt;

  factory AdminAuditEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return AdminAuditEntry(
      id: id,
      actorId: data['actor_id'] as String? ?? '',
      actorName: data['actor_name'] as String? ?? 'Admin',
      targetId: data['target_id'] as String? ?? '',
      targetName: data['target_name'] as String? ?? '',
      targetKind: data['target_kind'] as String? ?? 'user',
      oldStatus: data['old_status'] as String? ?? '',
      newStatus: data['new_status'] as String? ?? '',
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
