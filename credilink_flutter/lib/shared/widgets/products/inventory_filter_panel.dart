import 'package:flutter/material.dart';

import '../../../core/utils/inventory_stats.dart';
import '../../../models/product.dart';

enum InventorySortBy {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  stockAsc,
  stockDesc,
}

class InventoryFilters {
  const InventoryFilters({
    this.category,
    this.stockStatus,
    this.minPrice,
    this.maxPrice,
    this.productType,
    this.sortBy = InventorySortBy.nameAsc,
    this.searchTerm = '',
  });

  final String? category;
  final StockStatus? stockStatus;
  final double? minPrice;
  final double? maxPrice;
  final String? productType;
  final InventorySortBy sortBy;
  final String searchTerm;

  bool get hasActiveFilters =>
      (category != null && category!.isNotEmpty) ||
      stockStatus != null ||
      minPrice != null ||
      maxPrice != null ||
      (productType != null && productType!.isNotEmpty);

  InventoryFilters copyWith({
    String? category,
    StockStatus? stockStatus,
    bool clearStockStatus = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? productType,
    InventorySortBy? sortBy,
    String? searchTerm,
  }) {
    return InventoryFilters(
      category: category ?? this.category,
      stockStatus: clearStockStatus ? null : (stockStatus ?? this.stockStatus),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      productType: productType ?? this.productType,
      sortBy: sortBy ?? this.sortBy,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  InventoryFilters cleared() => const InventoryFilters();
}

List<Product> applyInventoryFilters(List<Product> products, InventoryFilters filters) {
  var result = products.where((p) => p.isActive).toList();

  final term = filters.searchTerm.trim().toLowerCase();
  if (term.isNotEmpty) {
    result = result
        .where((p) =>
            p.name.toLowerCase().contains(term) ||
            p.barcode.toLowerCase().contains(term) ||
            p.category.toLowerCase().contains(term) ||
            p.brand.toLowerCase().contains(term) ||
            p.description.toLowerCase().contains(term))
        .toList();
  }

  if (filters.category != null && filters.category!.isNotEmpty) {
    result = result.where((p) => p.category == filters.category).toList();
  }

  if (filters.stockStatus != null) {
    result = result.where((p) => stockStatusFor(p) == filters.stockStatus).toList();
  }

  if (filters.minPrice != null) {
    result = result.where((p) => p.sellingPrice >= filters.minPrice!).toList();
  }
  if (filters.maxPrice != null) {
    result = result.where((p) => p.sellingPrice <= filters.maxPrice!).toList();
  }

  if (filters.productType == 'barcode') {
    result = result.where((p) => p.hasBarcode).toList();
  } else if (filters.productType == 'no_barcode') {
    result = result.where((p) => !p.hasBarcode).toList();
  }

  result.sort((a, b) {
    switch (filters.sortBy) {
      case InventorySortBy.nameAsc:
        return a.name.compareTo(b.name);
      case InventorySortBy.nameDesc:
        return b.name.compareTo(a.name);
      case InventorySortBy.priceAsc:
        return a.sellingPrice.compareTo(b.sellingPrice);
      case InventorySortBy.priceDesc:
        return b.sellingPrice.compareTo(a.sellingPrice);
      case InventorySortBy.stockAsc:
        return a.stockQuantity.compareTo(b.stockQuantity);
      case InventorySortBy.stockDesc:
        return b.stockQuantity.compareTo(a.stockQuantity);
    }
  });

  return result;
}

List<String> extractCategories(List<Product> products) {
  final categories = products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList();
  categories.sort();
  return categories;
}

class InventoryFilterPanel extends StatefulWidget {
  const InventoryFilterPanel({
    super.key,
    required this.categories,
    required this.filters,
    required this.onChanged,
    this.showAdvanced = true,
  });

  final List<String> categories;
  final InventoryFilters filters;
  final ValueChanged<InventoryFilters> onChanged;
  final bool showAdvanced;

  @override
  State<InventoryFilterPanel> createState() => _InventoryFilterPanelState();
}

class _InventoryFilterPanelState extends State<InventoryFilterPanel> {
  bool _expanded = false;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _minPriceController = TextEditingController(
      text: widget.filters.minPrice?.toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.filters.maxPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.showAdvanced && widget.categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String?>(
              initialValue: widget.filters.category?.isEmpty == true ? null : widget.filters.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All categories')),
                ...widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => widget.onChanged(widget.filters.copyWith(category: v ?? '')),
            ),
          ),
        if (widget.showAdvanced) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.tune),
              label: Text(_expanded ? 'Hide Filters' : 'Advanced Filters'),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: widget.filters.category?.isEmpty == true ? null : widget.filters.category,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ...widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => widget.onChanged(widget.filters.copyWith(category: v ?? '')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<StockStatus?>(
                    initialValue: widget.filters.stockStatus,
                    decoration: const InputDecoration(labelText: 'Stock Status', isDense: true),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: StockStatus.inStock, child: Text('In Stock')),
                      DropdownMenuItem(value: StockStatus.lowStock, child: Text('Low Stock')),
                      DropdownMenuItem(value: StockStatus.outOfStock, child: Text('Out of Stock')),
                    ],
                    onChanged: (v) => widget.onChanged(
                      widget.filters.copyWith(stockStatus: v, clearStockStatus: v == null),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          decoration: const InputDecoration(labelText: 'Min Price', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onSubmitted: (v) {
                            final parsed = double.tryParse(v);
                            widget.onChanged(widget.filters.copyWith(
                              minPrice: parsed,
                              clearMinPrice: parsed == null,
                            ));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          decoration: const InputDecoration(labelText: 'Max Price', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onSubmitted: (v) {
                            final parsed = double.tryParse(v);
                            widget.onChanged(widget.filters.copyWith(
                              maxPrice: parsed,
                              clearMaxPrice: parsed == null,
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: widget.filters.productType?.isEmpty == true ? null : widget.filters.productType,
                    decoration: const InputDecoration(labelText: 'Product Type', isDense: true),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'barcode', child: Text('With Barcode')),
                      DropdownMenuItem(value: 'no_barcode', child: Text('No Barcode')),
                    ],
                    onChanged: (v) => widget.onChanged(widget.filters.copyWith(productType: v ?? '')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<InventorySortBy>(
                    initialValue: widget.filters.sortBy,
                    decoration: const InputDecoration(labelText: 'Sort By', isDense: true),
                    items: const [
                      DropdownMenuItem(value: InventorySortBy.nameAsc, child: Text('Name A-Z')),
                      DropdownMenuItem(value: InventorySortBy.nameDesc, child: Text('Name Z-A')),
                      DropdownMenuItem(value: InventorySortBy.priceAsc, child: Text('Price Low-High')),
                      DropdownMenuItem(value: InventorySortBy.priceDesc, child: Text('Price High-Low')),
                      DropdownMenuItem(value: InventorySortBy.stockAsc, child: Text('Stock Low-High')),
                      DropdownMenuItem(value: InventorySortBy.stockDesc, child: Text('Stock High-Low')),
                    ],
                    onChanged: (v) {
                      if (v != null) widget.onChanged(widget.filters.copyWith(sortBy: v));
                    },
                  ),
                ],
              ),
            ),
        ],
        if (widget.filters.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (widget.filters.category != null && widget.filters.category!.isNotEmpty)
                  Chip(
                    label: Text('Category: ${widget.filters.category}'),
                    onDeleted: () => widget.onChanged(widget.filters.copyWith(category: '')),
                  ),
                if (widget.filters.stockStatus != null)
                  Chip(
                    label: Text('Status: ${_statusLabel(widget.filters.stockStatus!)}'),
                    onDeleted: () => widget.onChanged(widget.filters.copyWith(clearStockStatus: true)),
                  ),
                if (widget.filters.productType != null && widget.filters.productType!.isNotEmpty)
                  Chip(
                    label: Text(widget.filters.productType == 'barcode' ? 'With Barcode' : 'No Barcode'),
                    onDeleted: () => widget.onChanged(widget.filters.copyWith(productType: '')),
                  ),
                ActionChip(
                  label: const Text('Clear All'),
                  onPressed: () => widget.onChanged(widget.filters.cleared()),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _statusLabel(StockStatus status) => switch (status) {
        StockStatus.inStock => 'In Stock',
        StockStatus.lowStock => 'Low Stock',
        StockStatus.outOfStock => 'Out of Stock',
      };
}

class StoreOwnerCategoryFilter extends StatelessWidget {
  const StoreOwnerCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String?>(
        initialValue: selectedCategory?.isEmpty == true ? null : selectedCategory,
        decoration: const InputDecoration(isDense: true),
        items: [
          const DropdownMenuItem(value: null, child: Text('All categories')),
          ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
