import 'package:cloud_firestore/cloud_firestore.dart';

import 'bulk_option.dart';

class Product {
  const Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.stockQuantity,
    required this.sellingPrice,
    required this.storeOwnerId,
    this.description = '',
    this.brand = '',
    this.minStockLevel = 0,
    this.maxStockLevel = 0,
    this.costPrice = 0,
    this.isActive = true,
    this.hasBarcode = true,
    this.customProductId,
    this.unitOfMeasure = 'piece',
    this.bulkUnit,
    this.piecesPerBulk,
    this.bulkSellingPrice,
    this.bulkOptions = const [],
    this.imageUrl,
  });

  final String? id;
  final String name;
  final String barcode;
  final String category;
  final int stockQuantity;
  final double sellingPrice;
  final double costPrice;
  final int minStockLevel;
  final int maxStockLevel;
  final String storeOwnerId;
  final String description;
  final String brand;
  final bool isActive;
  final bool hasBarcode;
  final String? customProductId;
  final String unitOfMeasure;
  final String? bulkUnit;
  final int? piecesPerBulk;
  final double? bulkSellingPrice;
  final List<BulkOption> bulkOptions;
  final String? imageUrl;

  bool get isLowStock => stockQuantity > 0 && stockQuantity <= minStockLevel;
  bool get isOutOfStock => stockQuantity <= 0;

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    final bulkRaw = data['bulk_options'] as List?;
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      category: data['category'] as String? ?? '',
      stockQuantity: (data['stock_quantity'] as num?)?.toInt() ?? 0,
      sellingPrice: (data['selling_price'] as num?)?.toDouble() ?? 0,
      costPrice: (data['cost_price'] as num?)?.toDouble() ?? 0,
      minStockLevel: (data['min_stock_level'] as num?)?.toInt() ?? 0,
      maxStockLevel: (data['max_stock_level'] as num?)?.toInt() ?? 0,
      storeOwnerId: data['store_owner_id'] as String? ?? '',
      description: data['description'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
      isActive: data['is_active'] as bool? ?? true,
      hasBarcode: data['has_barcode'] as bool? ?? true,
      customProductId: data['custom_product_id'] as String?,
      unitOfMeasure: data['unit_of_measure'] as String? ?? 'piece',
      bulkUnit: data['bulk_unit'] as String?,
      piecesPerBulk: (data['pieces_per_bulk'] as num?)?.toInt(),
      bulkSellingPrice: (data['bulk_selling_price'] as num?)?.toDouble(),
      bulkOptions: bulkRaw?.map((e) => BulkOption.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      imageUrl: data['image_url'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'barcode': barcode,
        'category': category,
        'stock_quantity': stockQuantity,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'min_stock_level': minStockLevel,
        'max_stock_level': maxStockLevel,
        'store_owner_id': storeOwnerId,
        'description': description,
        'brand': brand,
        'is_active': isActive,
        'has_barcode': hasBarcode,
        'custom_product_id': customProductId,
        'unit_of_measure': unitOfMeasure,
        'bulk_unit': bulkUnit,
        'pieces_per_bulk': piecesPerBulk,
        'bulk_selling_price': bulkSellingPrice,
        'bulk_options': bulkOptions.map((b) => b.toMap()).toList(),
        'image_url': imageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };
}
