import '../../models/product.dart';

class InventoryStats {
  const InventoryStats({
    required this.total,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final int total;
  final int inStock;
  final int lowStock;
  final int outOfStock;
}

enum StockStatus { inStock, lowStock, outOfStock }

StockStatus stockStatusFor(Product product) {
  if (product.isOutOfStock) return StockStatus.outOfStock;
  if (product.isLowStock) return StockStatus.lowStock;
  return StockStatus.inStock;
}

InventoryStats computeInventoryStats(List<Product> products) {
  final active = products.where((p) => p.isActive).toList();
  var inStock = 0;
  var lowStock = 0;
  var outOfStock = 0;

  for (final product in active) {
    switch (stockStatusFor(product)) {
      case StockStatus.inStock:
        inStock++;
      case StockStatus.lowStock:
        lowStock++;
      case StockStatus.outOfStock:
        outOfStock++;
    }
  }

  return InventoryStats(
    total: active.length,
    inStock: inStock,
    lowStock: lowStock,
    outOfStock: outOfStock,
  );
}

List<Product> filterLowStock(List<Product> products) =>
    products.where((p) => p.isActive && p.isLowStock).toList()..sort((a, b) => a.name.compareTo(b.name));

List<Product> filterOutOfStock(List<Product> products) =>
    products.where((p) => p.isActive && p.isOutOfStock).toList()..sort((a, b) => a.name.compareTo(b.name));

List<Product> filterInStock(List<Product> products) =>
    products.where((p) => p.isActive && stockStatusFor(p) == StockStatus.inStock).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
