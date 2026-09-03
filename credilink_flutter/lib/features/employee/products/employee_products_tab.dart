import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/inventory_stats.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/product.dart';
import '../../../models/stock_transaction.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/barcode_lookup_service.dart';
import '../../../shared/widgets/barcode/barcode_scanner_button.dart';
import '../../../shared/widgets/barcode/barcode_scanner_screen.dart'
    if (dart.library.html) '../../../shared/widgets/barcode/barcode_scanner_screen_web.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/products/barcode_scan_result_card.dart';
import '../../../shared/widgets/products/cred_product_card.dart';
import '../../../shared/widgets/products/inventory_filter_panel.dart';
import '../../../shared/widgets/products/inventory_summary_cards.dart';
import '../../../shared/widgets/products/low_stock_modal.dart';
import '../../../shared/widgets/products/out_of_stock_modal.dart';
import '../../../shared/widgets/products/product_detail_sheet.dart';
import '../../../shared/widgets/products/product_form_sheet.dart';
import '../../../shared/widgets/products/stock_adjust_sheet.dart';

final _barcodeLookupProvider = Provider((ref) => BarcodeLookupService());

class EmployeeProductsTab extends ConsumerStatefulWidget {
  const EmployeeProductsTab({super.key});

  @override
  ConsumerState<EmployeeProductsTab> createState() => _EmployeeProductsTabState();
}

class _EmployeeProductsTabState extends ConsumerState<EmployeeProductsTab> {
  final _searchController = TextEditingController();
  final _barcodeInputController = TextEditingController();
  final _picker = ImagePicker();
  InventoryFilters _filters = const InventoryFilters();
  String? _scannedBarcode;
  Product? _scannedLocalProduct;
  BarcodeLookupResult? _scannedLookupResult;
  String? _pendingImageUrl;
  bool _lookingUp = false;

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeInputController.dispose();
    super.dispose();
  }

  Product _productFromForm(ProductFormData data, String storeOwnerId, {Product? existing}) {
    return Product(
      id: existing?.id,
      name: data.name,
      barcode: data.barcode,
      category: data.category,
      stockQuantity: data.stockQuantity,
      sellingPrice: data.sellingPrice,
      costPrice: data.costPrice,
      minStockLevel: data.minStockLevel,
      maxStockLevel: data.maxStockLevel,
      storeOwnerId: storeOwnerId,
      description: data.description,
      brand: data.brand,
      bulkOptions: data.bulkOptions,
      isActive: existing?.isActive ?? true,
      hasBarcode: data.hasBarcode,
      customProductId: data.customProductId,
      unitOfMeasure: data.unitOfMeasure,
      bulkUnit: data.bulkUnit,
      piecesPerBulk: data.piecesPerBulk,
      bulkSellingPrice: data.bulkSellingPrice,
      imageUrl: data.imageUrl,
    );
  }

  Future<void> _addProduct(UserProfile profile, String storeOwnerId, {ExternalProductInfo? prefill, String? barcode}) async {
    await ProductFormSheet.show(
      context,
      title: 'Add Product',
      prefill: prefill,
      initialBarcode: barcode,
      initialImageUrl: _pendingImageUrl ?? prefill?.imageUrl,
      onBarcodeLookup: (code) => ref.read(_barcodeLookupProvider).lookup(code),
      onSave: (data) async {
        final product = _productFromForm(data, storeOwnerId);
        await ref.read(productRepositoryProvider).createProduct(product);
        ref.invalidate(currentStoreProductsProvider);
        if (mounted) CredSnackBar.show(context, 'Product created');
      },
    );
    _pendingImageUrl = null;
  }

  Future<void> _editProduct(Product product, String storeOwnerId) async {
    await ProductFormSheet.show(
      context,
      product: product,
      title: 'Edit Product',
      onBarcodeLookup: (code) => ref.read(_barcodeLookupProvider).lookup(code),
      onSave: (data) async {
        final updated = _productFromForm(data, storeOwnerId, existing: product);
        await ref.read(productRepositoryProvider).updateProduct(product.id!, updated);
        ref.invalidate(currentStoreProductsProvider);
        if (mounted) CredSnackBar.show(context, 'Product updated');
      },
    );
  }

  Future<void> _adjustStock(Product product, UserProfile profile, String storeOwnerId) async {
    await StockAdjustSheet.show(
      context,
      product: product,
      onAdjust: (result) async {
        final current = product.stockQuantity;
        final newQty = switch (result.type) {
          StockAdjustType.add => current + result.quantity,
          StockAdjustType.remove => current - result.quantity,
          StockAdjustType.set => result.quantity,
        };
        if (newQty < 0) throw Exception('Stock cannot be negative');
        await ref.read(productRepositoryProvider).updateStock(
              productId: product.id!,
              newQuantity: newQty,
              storeOwnerId: storeOwnerId,
              reason: result.reason ?? 'Manual adjustment',
              createdBy: profile.id,
            );
        ref.invalidate(currentStoreProductsProvider);
        if (mounted) CredSnackBar.show(context, 'Stock updated');
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    await ref.read(productRepositoryProvider).deactivateProduct(product.id!);
    ref.invalidate(currentStoreProductsProvider);
    if (mounted) CredSnackBar.show(context, 'Product deactivated');
  }

  Future<void> _openProductDetail(Product product, UserProfile profile, String storeOwnerId) async {
    List<StockTransaction> transactions = [];
    if (product.id != null) {
      transactions = await ref.read(productRepositoryProvider).getProductTransactions(product.id!);
    }
    if (!mounted) return;

    ProductDetailSheet.show(
      context,
      product: product,
      transactions: transactions,
      onEdit: () {
        Navigator.pop(context);
        _editProduct(product, storeOwnerId);
      },
      onAdjustStock: () {
        Navigator.pop(context);
        _adjustStock(product, profile, storeOwnerId);
      },
      onDelete: () async {
        Navigator.pop(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Deactivate "${product.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed == true) await _deleteProduct(product);
      },
    );
  }

  Future<void> _handleBarcodeLookup(String barcode, String storeOwnerId) async {
    if (barcode.trim().isEmpty) return;
    setState(() {
      _lookingUp = true;
      _scannedBarcode = barcode.trim();
      _scannedLocalProduct = null;
      _scannedLookupResult = null;
    });

    try {
      final local = await ref.read(productRepositoryProvider).findByBarcode(storeOwnerId, barcode.trim());
      BarcodeLookupResult? external;
      if (local == null) {
        external = await ref.read(_barcodeLookupProvider).lookup(barcode.trim());
      }
      if (mounted) {
        setState(() {
          _scannedLocalProduct = local;
          _scannedLookupResult = external;
        });
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _clearScanResult() {
    setState(() {
      _scannedBarcode = null;
      _scannedLocalProduct = null;
      _scannedLookupResult = null;
      _barcodeInputController.clear();
    });
  }

  Future<void> _captureImage(UserProfile profile, String storeOwnerId) async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    _pendingImageUrl = file.path;
    if (mounted) {
      CredSnackBar.show(context, 'Image captured — opening product form');
      await _addProduct(profile, storeOwnerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final productsAsync = ref.watch(currentStoreProductsProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (profile) {
        if (profile == null) return const EmptyState(message: 'No profile');
        final storeOwnerId = resolveStoreOwnerId(profile);

        return CredAsyncView<List<Product>>(
          asyncValue: productsAsync,
          emptyMessage: 'No products',
          onRetry: () => ref.invalidate(currentStoreProductsProvider),
          builder: (products) {
            final active = products.where((p) => p.isActive).toList();
            final stats = computeInventoryStats(active);
            final lowStock = filterLowStock(active);
            final outOfStock = filterOutOfStock(active);
            final categories = extractCategories(active);
            final filters = _filters.copyWith(searchTerm: _searchController.text);
            final filtered = applyInventoryFilters(active, filters);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentStoreProductsProvider);
                await ref.read(currentStoreProductsProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: CredTheme.pagePadding.copyWith(bottom: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CredSection(
                            title: 'Overview',
                            subtitle: 'Inventory at a glance',
                            child: InventorySummaryCards(
                              stats: stats,
                              onLowStockTap: lowStock.isEmpty
                                  ? null
                                  : () => LowStockModal.show(
                                        context,
                                        products: lowStock,
                                        onViewProduct: (p) {
                                          Navigator.pop(context);
                                          _openProductDetail(p, profile, storeOwnerId);
                                        },
                                        onAdjustStock: (p) {
                                          Navigator.pop(context);
                                          _adjustStock(p, profile, storeOwnerId);
                                        },
                                        onFilterList: () {
                                          Navigator.pop(context);
                                          setState(() =>
                                              _filters = _filters.copyWith(stockStatus: StockStatus.lowStock));
                                        },
                                      ),
                              onOutOfStockTap: outOfStock.isEmpty
                                  ? null
                                  : () => OutOfStockModal.show(
                                        context,
                                        products: outOfStock,
                                        onViewProduct: (p) {
                                          Navigator.pop(context);
                                          _openProductDetail(p, profile, storeOwnerId);
                                        },
                                        onAdjustStock: (p) {
                                          Navigator.pop(context);
                                          _adjustStock(p, profile, storeOwnerId);
                                        },
                                        onFilterList: () {
                                          Navigator.pop(context);
                                          setState(() =>
                                              _filters = _filters.copyWith(stockStatus: StockStatus.outOfStock));
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
                                  label: 'Add Product',
                                  icon: Icons.add,
                                  onPressed: () => _addProduct(profile, storeOwnerId),
                                ),
                                CredQuickAction(
                                  label: 'Scan Barcode',
                                  icon: Icons.qr_code_scanner,
                                  onPressed: () async {
                                    final code = await scanBarcode(context);
                                    if (code != null) {
                                      _barcodeInputController.text = code;
                                      await _handleBarcodeLookup(code, storeOwnerId);
                                    }
                                  },
                                ),
                                CredQuickAction(
                                  label: 'Low Stock',
                                  icon: Icons.warning_amber,
                                  onPressed: lowStock.isEmpty
                                      ? null
                                      : () => LowStockModal.show(
                                            context,
                                            products: lowStock,
                                            onViewProduct: (p) {
                                              Navigator.pop(context);
                                              _openProductDetail(p, profile, storeOwnerId);
                                            },
                                            onAdjustStock: (p) {
                                              Navigator.pop(context);
                                              _adjustStock(p, profile, storeOwnerId);
                                            },
                                            onFilterList: () {
                                              Navigator.pop(context);
                                              setState(() =>
                                                  _filters = _filters.copyWith(stockStatus: StockStatus.lowStock));
                                            },
                                          ),
                                ),
                                CredQuickAction(
                                  label: 'Out of Stock',
                                  icon: Icons.remove_shopping_cart,
                                  onPressed: outOfStock.isEmpty
                                      ? null
                                      : () => setState(
                                            () => _filters =
                                                _filters.copyWith(stockStatus: StockStatus.outOfStock),
                                          ),
                                ),
                                CredQuickAction(
                                  label: 'Camera',
                                  icon: Icons.camera_alt,
                                  onPressed: () => _captureImage(profile, storeOwnerId),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: CredTheme.spaceLg),
                          CredSection(
                            title: 'Catalog',
                            subtitle: '${filtered.length} shown',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Material(
                                  color: CredTheme.cardBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(CredTheme.radiusCard),
                                    side: const BorderSide(color: CredTheme.border),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceSm),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _barcodeInputController,
                                            decoration: const InputDecoration(
                                              hintText: 'Enter barcode manually',
                                              isDense: true,
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (v) => _handleBarcodeLookup(v, storeOwnerId),
                                          ),
                                        ),
                                        if (_lookingUp)
                                          const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        else
                                          BarcodeScannerButton(
                                            onScanned: (code) {
                                              _barcodeInputController.text = code;
                                              _handleBarcodeLookup(code, storeOwnerId);
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.search),
                                          onPressed: () =>
                                              _handleBarcodeLookup(_barcodeInputController.text, storeOwnerId),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_scannedBarcode != null)
                                  BarcodeScanResultCard(
                                    barcode: _scannedBarcode!,
                                    localProduct: _scannedLocalProduct,
                                    lookupResult: _scannedLookupResult,
                                    onDismiss: _clearScanResult,
                                    onView: () {
                                      if (_scannedLocalProduct != null) {
                                        _openProductDetail(_scannedLocalProduct!, profile, storeOwnerId);
                                      }
                                    },
                                    onAdd: () {
                                      final prefill = _scannedLookupResult?.product;
                                      _addProduct(
                                        profile,
                                        storeOwnerId,
                                        prefill: prefill,
                                        barcode: _scannedBarcode,
                                      );
                                    },
                                  ),
                                const SizedBox(height: CredTheme.spaceSm),
                                CredSearchField(
                                  controller: _searchController,
                                  hint: 'Search products…',
                                  onChanged: (_) => setState(() {}),
                                ),
                                InventoryFilterPanel(
                                  categories: categories,
                                  filters: filters,
                                  showAdvanced: true,
                                  onChanged: (f) =>
                                      setState(() => _filters = f.copyWith(searchTerm: _searchController.text)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: CredTheme.spaceSm),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(message: 'No matching products'),
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
                          (context, i) {
                            final product = filtered[i];
                            return CredProductCard(
                              product: product,
                              onTap: () => _openProductDetail(product, profile, storeOwnerId),
                              actions: [
                                CredProductAction(
                                  label: 'View',
                                  icon: Icons.visibility_outlined,
                                  onSelected: () =>
                                      _openProductDetail(product, profile, storeOwnerId),
                                ),
                                CredProductAction(
                                  label: 'Edit',
                                  icon: Icons.edit_outlined,
                                  onSelected: () => _editProduct(product, storeOwnerId),
                                ),
                                CredProductAction(
                                  label: 'Adjust stock',
                                  icon: Icons.inventory_outlined,
                                  onSelected: () =>
                                      _adjustStock(product, profile, storeOwnerId),
                                ),
                                CredProductAction(
                                  label: 'Deactivate',
                                  icon: Icons.delete_outline,
                                  onSelected: () => _deleteProduct(product),
                                ),
                              ],
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
