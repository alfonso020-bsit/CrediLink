import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../products/cred_product_card.dart';

/// POS catalog tile — delegates to [CredProductCard].
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CredProductCard(
      product: product,
      onTap: onTap,
      showCategory: true,
    );
  }
}
