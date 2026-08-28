import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_transaction.dart';

class ProductRepository {
  ProductRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<Product>> getProductsByStore(String storeOwnerId) async {
    final snap = await _firestore
        .collection('products')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();
    return snap.docs.map((d) => Product.fromFirestore(d.id, d.data())).toList();
  }

  Future<Product?> findByBarcode(String storeOwnerId, String barcode) =>
      getProductByBarcode(barcode, storeOwnerId);

  Future<List<StockTransaction>> getProductTransactions(
    String productId, {
    int limit = 10,
  }) async {
    final snap = await _firestore
        .collection('stock_transactions')
        .where('product_id', isEqualTo: productId)
        .limit(limit)
        .get();

    final transactions = snap.docs
        .map((d) => StockTransaction.fromFirestore(d.id, d.data()))
        .toList();

    transactions.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return transactions;
  }

  Future<Product?> getProductByBarcode(String barcode, String storeOwnerId) async {
    for (final variation in _barcodeVariations(barcode)) {
      final snap = await _firestore
          .collection('products')
          .where('barcode', isEqualTo: variation)
          .where('store_owner_id', isEqualTo: storeOwnerId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return Product.fromFirestore(doc.id, doc.data());
      }
    }
    return null;
  }

  Future<String> createProduct(Product product) async {
    if (product.hasBarcode && product.barcode.isNotEmpty) {
      final existing = await getProductByBarcode(product.barcode, product.storeOwnerId);
      if (existing != null) {
        throw Exception('Product with this barcode already exists in your store');
      }
    }

    final docRef = _firestore.collection('products').doc();
    final data = {
      ...product.toFirestore(),
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateProduct(String productId, Product product) async {
    await _firestore.collection('products').doc(productId).set(
          product.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<void> deactivateProduct(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStock({
    required String productId,
    required int newQuantity,
    required String storeOwnerId,
    required String reason,
    String type = 'adjustment',
    String? createdBy,
    String? reference,
  }) async {
    final productRef = _firestore.collection('products').doc(productId);
    final productDoc = await productRef.get();
    if (!productDoc.exists) throw Exception('Product not found');

    final data = productDoc.data()!;
    final previousStock = (data['stock_quantity'] as num?)?.toInt() ?? 0;
    final adjustment = newQuantity - previousStock;

    await productRef.update({
      'stock_quantity': newQuantity,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final transaction = StockTransaction(
      productId: productId,
      storeOwnerId: storeOwnerId,
      type: type,
      quantity: adjustment.abs(),
      previousStock: previousStock,
      newStock: newQuantity,
      reason: reason,
      reference: reference,
      createdBy: createdBy,
    );

    await _firestore.collection('stock_transactions').add({
      ...transaction.toFirestore(),
      'product_name': data['name'],
      'change_type': adjustment >= 0 ? 'increase' : 'decrease',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Product>> getLowStockProducts(String storeOwnerId) async {
    final products = await getProductsByStore(storeOwnerId);
    return products
        .where((p) => p.isActive && p.isLowStock)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<Product>> getOutOfStockProducts(String storeOwnerId) async {
    final products = await getProductsByStore(storeOwnerId);
    return products.where((p) => p.isActive && p.isOutOfStock).toList();
  }

  Future<List<Map<String, dynamic>>> getCashSales(String storeOwnerId) async {
    final snap = await _firestore
        .collection('cash_products')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<SaleRecord>> getSalesByCustomer(
    String customerId, {
    String? customerName,
  }) async {
    final debtSnap = await _firestore
        .collection('debt_products')
        .where('customer_id', isEqualTo: customerId)
        .get();

    var cashSnap = await _firestore
        .collection('cash_products')
        .where('customer_id', isEqualTo: customerId)
        .get();

    if (cashSnap.docs.isEmpty && customerName != null && customerName.isNotEmpty) {
      cashSnap = await _firestore
          .collection('cash_products')
          .where('customerName', isEqualTo: customerName)
          .get();
    }

    final sales = <SaleRecord>[
      ...cashSnap.docs.map((d) => SaleRecord.fromCashMap(d.id, d.data())),
      ...debtSnap.docs.map((d) => SaleRecord.fromDebtMap(d.id, d.data())),
    ];

    sales.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return sales;
  }

  Future<List<SaleRecord>> getSalesForStore(String storeOwnerId) async {
    final cashSnap = await _firestore
        .collection('cash_products')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();
    final debtSnap = await _firestore
        .collection('debt_products')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();

    final sales = <SaleRecord>[
      ...cashSnap.docs.map((d) => SaleRecord.fromCashMap(d.id, d.data())),
      ...debtSnap.docs.map((d) => SaleRecord.fromDebtMap(d.id, d.data())),
    ];

    sales.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return sales;
  }

  Future<String> completeCashSale({
    required String saleId,
    required String storeOwnerId,
    required String employeeId,
    required List<CartItem> items,
    required double total,
    double amountPaid = 0,
    double change = 0,
    String? customerName,
    String? customerPhone,
    String? receiptImage,
  }) async {
    await _decrementStockForItems(
      items: items,
      storeOwnerId: storeOwnerId,
      employeeId: employeeId,
      reference: saleId,
    );

    final saleData = {
      'id': saleId,
      'total': total,
      'paymentMethod': 'cash',
      'amountPaid': amountPaid,
      'change': change,
      'customerName': customerName ?? '',
      'customerPhone': customerPhone ?? '',
      'status': 'completed',
      'receipt_image': receiptImage ?? '',
      'store_owner_id': storeOwnerId,
      'employee_id': employeeId,
      'items': items.map((i) => i.toSaleLineItem()).toList(),
      'created_at': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('cash_products').doc(saleId).set(saleData);
    return saleId;
  }

  Future<String> completeDebtSale({
    required String saleId,
    required String storeOwnerId,
    required String employeeId,
    required String customerId,
    required List<CartItem> items,
    required double total,
    required double remainingBalance,
    double initialPayment = 0,
    DateTime? dueDate,
    String? customerName,
    String? customerPhone,
    String? receiptImage,
  }) async {
    await _decrementStockForItems(
      items: items,
      storeOwnerId: storeOwnerId,
      employeeId: employeeId,
      reference: saleId,
    );

    final paymentStatus = remainingBalance <= 0
        ? 'paid'
        : initialPayment > 0
            ? 'partially_paid'
            : 'unpaid';

    final saleData = {
      'id': saleId,
      'total': total,
      'total_amount': total,
      'paymentMethod': 'debt',
      'customer_id': customerId,
      'customerName': customerName ?? '',
      'customerPhone': customerPhone ?? '',
      'status': remainingBalance <= 0 ? 'paid' : 'pending',
      'payment_status': paymentStatus,
      'initialPayment': initialPayment,
      'remainingBalance': remainingBalance,
      'originalTotal': total,
      'receipt_image': receiptImage ?? '',
      'store_owner_id': storeOwnerId,
      'employee_id': employeeId,
      'items': items.map((i) => i.toSaleLineItem()).toList(),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'created_at': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('debt_products').doc(saleId).set(saleData);
    return saleId;
  }

  Future<void> _decrementStockForItems({
    required List<CartItem> items,
    required String storeOwnerId,
    required String employeeId,
    required String reference,
  }) async {
    for (final item in items) {
      final productId = item.product.id;
      if (productId == null) {
        throw Exception('Product ID missing for ${item.product.name}');
      }

      final quantityToDeduct = item.totalPieces;
      final newStock = item.product.stockQuantity - quantityToDeduct;
      if (newStock < 0) {
        throw Exception(
          'Insufficient stock for ${item.product.name}. '
          'Available: ${item.product.stockQuantity}, Required: $quantityToDeduct',
        );
      }

      await updateStock(
        productId: productId,
        newQuantity: newStock,
        storeOwnerId: storeOwnerId,
        reason: 'Sale $reference',
        type: 'stock_out',
        createdBy: employeeId,
        reference: reference,
      );
    }
  }

  List<String> _barcodeVariations(String barcode) {
    final clean = barcode.trim();
    final normalized = _normalizeBarcode(clean);
    return {
      clean,
      normalized,
      clean.padLeft(13, '0'),
      clean.padLeft(12, '0'),
    }.toList();
  }

  String _normalizeBarcode(String barcode) {
    if (barcode.length == 11) return '0$barcode';
    return barcode;
  }
}
