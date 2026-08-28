import 'package:credilink_flutter/models/bulk_option.dart';
import 'package:credilink_flutter/models/cart_item.dart';
import 'package:credilink_flutter/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = Product(
    id: 'p1',
    name: 'Soda',
    barcode: '123',
    category: 'Beverages',
    stockQuantity: 100,
    sellingPrice: 15,
    storeOwnerId: 'store1',
    bulkOptions: [const BulkOption(label: 'pack', piecesPerBulk: 6, price: 80)],
  );

  test('piece pricing subtotal', () {
    final item = CartItem(product: product, quantity: 3);
    expect(item.subtotal, 45);
    expect(item.totalPieces, 3);
  });

  test('bulk pricing subtotal', () {
    final item = CartItem(
      product: product,
      quantity: 2,
      pricingOption: 'bulk',
      bulkOption: product.bulkOptions.first,
    );
    expect(item.subtotal, 160);
    expect(item.totalPieces, 12);
  });
}
