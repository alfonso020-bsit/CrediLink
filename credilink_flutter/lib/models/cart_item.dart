import 'bulk_option.dart';
import 'product.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.pricingOption = 'piece',
    this.bulkOption,
  });

  final Product product;
  int quantity;
  String pricingOption;
  BulkOption? bulkOption;

  int get totalPieces {
    if (pricingOption == 'bulk' && bulkOption != null) {
      return quantity * bulkOption!.piecesPerBulk;
    }
    return quantity;
  }

  double get unitPrice {
    if (pricingOption == 'bulk' && bulkOption != null) {
      return bulkOption!.price;
    }
    return product.sellingPrice;
  }

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toSaleLineItem() => {
        'product_id': product.id ?? '',
        'product_name': product.name,
        'product_barcode': product.barcode,
        'product_category': product.category,
        'quantity': quantity,
        'unit': pricingOption == 'bulk' ? bulkOption?.label ?? 'bulk' : 'piece',
        'price': unitPrice,
        'subtotal': subtotal,
        'pricing_option': pricingOption,
        'total_pieces': totalPieces,
      };
}
