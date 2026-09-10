import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/masquerade/masquerade_provider.dart';
import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/inventory_stats.dart';
import '../../../models/product.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/inventory_pdf_service.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/layout/cred_filter_chips.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/products/cred_product_card.dart';
import '../../../shared/widgets/products/inventory_filter_panel.dart';
import '../../../shared/widgets/products/inventory_summary_cards.dart';
import '../../../shared/widgets/products/low_stock_modal.dart';
import '../../../shared/widgets/products/out_of_stock_modal.dart';
import '../../../shared/widgets/products/product_detail_sheet.dart';

class StoreOwnerInventoryTab extends ConsumerStatefulWidget {
  const StoreOwnerInventoryTab({super.key});

  @override
  ConsumerState<StoreOwnerInventoryTab> createState() => _StoreOwnerInventoryTabState();
}

class _StoreOwnerInventoryTabState extends ConsumerState<StoreOwnerInventoryTab> {
  final _searchController = TextEditingController();
  String? _categoryFilter;
  StockStatus? _stockFilter;
  bool _exporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    var result = products.where((p) => p.isActive).toList();
    final term = _searchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(term) ||
                p.barcode.toLowerCase().contains(term) ||
                p.category.toLowerCase().contains(term) ||
                p.brand.toLowerCase().contains(term),
          )
          .toList();
    }
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      result = result.where((p) => p.category == _categoryFilter).toList();
    }
    if (_stockFilter != null) {
      result = result.where((p) => stockStatusFor(p) == _stockFilter).toList();
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _stockFilter = null;
      _searchController.clear();
    });
  }

  Future<void> _exportPdf(List<Product> products, UserProfile profile) async {
    setState(() => _exporting = true);
    try {
      await InventoryPdfService().exportInventory(
        products: products,
        storeName: profile.storeName ?? 'My Store',
        ownerName: profile.fullName,
      );
      if (mounted) CredSnackBar.show(context, 'PDF report generated');
    } catch (e) {
      if (mounted) CredSnackBar.show(context, 'Failed to export PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(viewingProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (profile) {
        if (profile == null) return const EmptyState(message: 'No profile');

        final storeOwnerId = profile.id;
        final productsAsync = ref.watch(storeProductsProvider(storeOwnerId));

        return CredAsyncView<List<Product>>(
          asyncValue: productsAsync,
          emptyMessage: 'No products',
          onRetry: () => ref.invalidate(storeProductsProvider(storeOwnerId)),
          builder: (products) {
            final active = products.where((p) => p.isActive).toList();
            final stats = computeInventoryStats(active);
            final lowStock = filterLowStock(active);
            final outOfStock = filterOutOfStock(active);
            final filtered = _filterProducts(active);
            final categories = extractCategories(active);
            final hasFilter = (_categoryFilter != null && _categoryFilter!.isNotEmpty) ||
                _stockFilter != null ||
                _searchController.text.trim().isNotEmpty;

            return CredTabPageLayoutBuilder(
              onRefresh: () async {
                ref.invalidate(storeProductsProvider(storeOwnerId));
                await ref.read(storeProductsProvider(storeOwnerId).future);
              },
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: CredTheme.spaceMd),
                  CredSection(
                    title: 'Overview',
                    subtitle: 'Stock health at a glance',
                    child: InventorySummaryCards(
                      stats: stats,
                      onLowStockTap: lowStock.isEmpty
                          ? null
                          : () => LowStockModal.show(
                                context,
                                products: lowStock,
                                readOnly: true,
                                onViewProduct: (p) {
                                  Navigator.pop(context);
                                  ProductDetailSheet.show(context, product: p, readOnly: true);
                                },
                                onFilterList: () {
                                  Navigator.pop(context);
                                  setState(() => _stockFilter = StockStatus.lowStock);
                                },
                              ),
                      onOutOfStockTap: outOfStock.isEmpty
                          ? null
                          : () => OutOfStockModal.show(
                                context,
                                products: outOfStock,
                                readOnly: true,
                                onViewProduct: (p) {
                                  Navigator.pop(context);
                                  ProductDetailSheet.show(context, product: p, readOnly: true);
                                },
                                onFilterList: () {
                                  Navigator.pop(context);
                                  setState(() => _stockFilter = StockStatus.outOfStock);
                                },
                              ),
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceLg),
                  CredSection(
                    title: 'Quick Actions',
                    child: CredQuickActionGrid(
                      actions: [
                        CredQuickAction(
                          label: 'Low Stock',
                          icon: Icons.warning_amber,
                          onPressed: lowStock.isEmpty
                              ? null
                              : () => LowStockModal.show(
                                    context,
                                    products: lowStock,
                                    readOnly: true,
                                    onViewProduct: (p) {
                                      Navigator.pop(context);
                                      ProductDetailSheet.show(context, product: p, readOnly: true);
                                    },
                                    onFilterList: () {
                                      Navigator.pop(context);
                                      setState(() => _stockFilter = StockStatus.lowStock);
                                    },
                                  ),
                        ),
                        CredQuickAction(
                          label: 'Out of Stock',
                          icon: Icons.remove_shopping_cart,
                          onPressed: outOfStock.isEmpty
                              ? null
                              : () {
                                  setState(() => _stockFilter = StockStatus.outOfStock);
                                  CredSnackBar.show(
                                    context,
                                    'Showing ${outOfStock.length} out of stock products',
                                  );
                                },
                        ),
                        CredQuickAction(
                          label: _exporting ? 'Exporting…' : 'Export PDF',
                          icon: Icons.picture_as_pdf,
                          onPressed: _exporting ? null : () => _exportPdf(active, profile),
                        ),
                        CredQuickAction(
                          label: 'Show All',
                          icon: Icons.list,
                          onPressed: hasFilter ? _clearFilters : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceLg),
                  CredSection(
                    title: 'Products',
                    subtitle: '${filtered.length} shown',
                    child: Column(
                      children: [
                        CredSearchField(
                          controller: _searchController,
                          hint: 'Search name, barcode, category, brand',
                          onChanged: (_) => setState(() {}),
                        ),
                        StoreOwnerCategoryFilter(
                          categories: categories,
                          selectedCategory: _categoryFilter,
                          onChanged: (v) => setState(() => _categoryFilter = v),
                        ),
                        if (hasFilter)
                          Padding(
                            padding: const EdgeInsets.only(top: CredTheme.spaceXs),
                            child: CredFilterChips(
                              onClearAll: _clearFilters,
                              chips: [
                                if (_stockFilter != null)
                                  CredFilterChipData(
                                    label: _stockFilter == StockStatus.lowStock
                                        ? 'Low Stock'
                                        : 'Out of Stock',
                                    onDeleted: () => setState(() => _stockFilter = null),
                                  ),
                                if (_categoryFilter != null && _categoryFilter!.isNotEmpty)
                                  CredFilterChipData(
                                    label: 'Category: $_categoryFilter',
                                    onDeleted: () => setState(() => _categoryFilter = null),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                ],
              ),
              slivers: [
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(message: 'No products found'),
                  )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        CredTheme.spaceMd,
                        0,
                        CredTheme.spaceMd,
                        CredTheme.spaceLg,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: CredProductGrid.gridDelegate(),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => CredProductCard(
                            product: filtered[i],
                            onTap: () => ProductDetailSheet.show(
                              context,
                              product: filtered[i],
                              readOnly: true,
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}
