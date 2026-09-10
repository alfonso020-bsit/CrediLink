import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/product.dart';
import '../../../models/store_profile.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_modal.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
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
    return showCredModal(
      context: context,
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
    final storeName = widget.store.displayName;
    final location = CustomerHelpers.storeLocation(widget.store);

    return CredSheetScaffold(
      title: storeName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CredAvatar(name: storeName, imageUrl: widget.store.storeImage, radius: 28),
              const SizedBox(width: CredTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.store.ownerName != null &&
                        widget.store.ownerName!.trim().isNotEmpty)
                      Text(
                        'Owner: ${widget.store.ownerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CredTheme.bodyMutedStyle(context),
                      ),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CredTheme.bodyMutedStyle(context),
                      ),
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
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: CredTheme.spaceSm),
          DropdownButtonFormField<String?>(
            key: ValueKey('cat-$_selectedCategory'),
            initialValue: _selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'All categories',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All categories', overflow: TextOverflow.ellipsis),
              ),
              ..._categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
          const SizedBox(height: CredTheme.spaceSm),
          DropdownButtonFormField<_ProductSort>(
            key: ValueKey('sort-$_sortBy'),
            initialValue: _sortBy,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'Sort by',
            ),
            items: const [
              DropdownMenuItem(value: _ProductSort.name, child: Text('Sort: Name')),
              DropdownMenuItem(value: _ProductSort.priceLow, child: Text('Sort: Price low–high')),
              DropdownMenuItem(value: _ProductSort.priceHigh, child: Text('Sort: Price high–low')),
              DropdownMenuItem(value: _ProductSort.category, child: Text('Sort: Category')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sortBy = value);
            },
          ),
          const SizedBox(height: CredTheme.spaceMd),
          Text(
            '${products.length} product${products.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CredTheme.spaceSm),
          if (products.isEmpty)
            const EmptyState(message: 'No products found', icon: Icons.inventory_2_outlined)
          else
            CredProductGrid(
              products: products,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, product, _) => CredProductCard(product: product),
            ),
        ],
      ),
    );
  }
}
