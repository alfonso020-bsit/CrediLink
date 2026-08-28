import 'package:credilink_flutter/core/utils/inventory_stats.dart';
import 'package:credilink_flutter/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  required String name,
  int stock = 10,
  int minStock = 5,
  bool active = true,
}) {
  return Product(
    name: name,
    barcode: '123',
    category: 'Food',
    stockQuantity: stock,
    sellingPrice: 10,
    storeOwnerId: 'store1',
    minStockLevel: minStock,
    isActive: active,
  );
}

void main() {
  group('computeInventoryStats', () {
    test('counts total, in stock, low stock, and out of stock', () {
      final products = [
        _product(name: 'A', stock: 20, minStock: 5),
        _product(name: 'B', stock: 3, minStock: 5),
        _product(name: 'C', stock: 0, minStock: 5),
        _product(name: 'D', stock: 8, minStock: 5, active: false),
      ];

      final stats = computeInventoryStats(products);

      expect(stats.total, 3);
      expect(stats.inStock, 1);
      expect(stats.lowStock, 1);
      expect(stats.outOfStock, 1);
    });
  });

  group('stockStatusFor', () {
    test('returns correct status', () {
      expect(stockStatusFor(_product(name: 'A', stock: 0)), StockStatus.outOfStock);
      expect(stockStatusFor(_product(name: 'B', stock: 3, minStock: 5)), StockStatus.lowStock);
      expect(stockStatusFor(_product(name: 'C', stock: 10, minStock: 5)), StockStatus.inStock);
    });
  });
}
