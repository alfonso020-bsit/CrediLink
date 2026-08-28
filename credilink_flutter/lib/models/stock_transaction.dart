import 'package:cloud_firestore/cloud_firestore.dart';

class StockTransaction {
  const StockTransaction({
    required this.productId,
    required this.storeOwnerId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.reason,
    this.reference,
    this.createdBy,
    this.createdAt,
    this.productName,
    this.changeType,
  });

  final String productId;
  final String storeOwnerId;
  final String type;
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? reason;
  final String? reference;
  final String? createdBy;
  final DateTime? createdAt;
  final String? productName;
  final String? changeType;

  factory StockTransaction.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['created_at'];
    return StockTransaction(
      productId: data['product_id'] as String? ?? '',
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      type: data['type'] as String? ?? 'adjustment',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      previousStock: (data['previous_stock'] as num?)?.toInt() ?? 0,
      newStock: (data['new_stock'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String?,
      reference: data['reference'] as String?,
      createdBy: data['created_by'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      productName: data['product_name'] as String?,
      changeType: data['change_type'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'product_id': productId,
        'store_owner_id': storeOwnerId,
        'type': type,
        'quantity': quantity,
        'previous_stock': previousStock,
        'new_stock': newStock,
        'reason': reason,
        'reference': reference,
        'created_by': createdBy,
        'created_at': DateTime.now(),
      };
}
