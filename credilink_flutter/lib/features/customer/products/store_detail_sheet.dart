import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/product.dart';
import '../../../models/store_profile.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/products/cred_product_card.dart';
import '../customer_helpers.dart';

enum _ProductSort { name, priceLow, priceHigh, category }

class StoreDetailSheet extends StatefulWidget {
  const StoreDetailSheet({
    super.key,
    required this.store,
    required this.products,
  });

  final StoreProfile store;
  final List<Product> products;

  static Future<void> show(
    BuildContext context, {
    required StoreProfile store,
    required List<Product> products,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StoreDetailSheet(store: store, products: products),
    );
  }

  @override
  State<StoreDetailSheet> createState() => _StoreDetailSheetState();
}

class _StoreDetailSheetState extends State<StoreDetailSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;
  _ProductSort _sortBy = _ProductSort.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final categories = widget.products
        .where((p) => p.isActive && p.category.isNotEmpty)
        .map((p) => p.category)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  List<Product> get _filteredProducts {
    var products = widget.products.where((p) => p.isActive).toList();

    if (_selectedCategory != null) {
      products = products.where((p) => p.category == _selectedCategory).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      products = products
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q) ||
                p.barcode.toLowerCase().contains(q),
          )
          .toList();
    }

    products.sort((a, b) {
      switch (_sortBy) {
        case _ProductSort.priceLow:
          return a.sellingPrice.compareTo(b.sellingPrice);
        case _ProductSort.priceHigh:
          return b.sellingPrice.compareTo(a.sellingPrice);
        case _ProductSort.category:
          final categoryCompare = a.category.compareTo(b.category);
          return categoryCompare != 0 ? categoryCompare : a.name.compareTo(b.name);
        case _ProductSort.name:
          return a.name.compareTo(b.name);
      }
    });

    return products;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: CredTheme.pagePadding,
          children: [
            Row(
              children: [
                CredAvatar(name: widget.store.storeName, imageUrl: widget.store.storeImage, radius: 28),
                const SizedBox(width: CredTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.store.storeName, style: Theme.of(context).textTheme.titleLarge),
                      if (widget.store.ownerName != null) Text('Owner: ${widget.store.ownerName}'),
                      Text(CustomerHelpers.storeLocation(widget.store)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CredTheme.spaceMd),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search products in store...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_selectedCategory),
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ..._categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ),
                const SizedBox(width: CredTheme.spaceSm),
                Expanded(
                  child: DropdownButtonFormField<_ProductSort>(
                    key: ValueKey(_sortBy),
                    initialValue: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _ProductSort.name,
                        child: Text('Name'),
                      ),
                      DropdownMenuItem(
                        value: _ProductSort.priceLow,
                        child: Text('Price: Low to High'),
                      ),
                      DropdownMenuItem(
                        value: _ProductSort.priceHigh,
                        child: Text('Price: High to Low'),
                      ),
                      DropdownMenuItem(
                        value: _ProductSort.category,
                        child: Text('Category'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sortBy = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: CredTheme.spaceMd),
            Text(
              '${products.length} product${products.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CredTheme.spaceSm),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(CredTheme.spaceLg),
                child: Center(child: Text('No products found')),
              )
            else
              CredProductGrid(
                products: products,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, product, _) => CredProductCard(product: product),
              ),
          ],
        );
      },
    );
  }
}
