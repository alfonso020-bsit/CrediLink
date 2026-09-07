import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/bulk_option.dart';
import '../../../models/cart_item.dart';
import '../../../models/customer_profile.dart';
import '../../../models/product.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/barcode/barcode_input_card.dart';
import '../../../shared/widgets/barcode/barcode_scanner_screen.dart'
    if (dart.library.html) '../../../shared/widgets/barcode/barcode_scanner_screen_web.dart';
import '../../../shared/widgets/commerce/checkout_sheet.dart';
import '../../../shared/widgets/commerce/sale_cart_panel.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/customers/customer_picker_sheet.dart';
import '../../../shared/widgets/customers/debt_customer_register_sheet.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/products/cred_product_card.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';

class EmployeePosScreen extends ConsumerStatefulWidget {
  const EmployeePosScreen({super.key});

  @override
  ConsumerState<EmployeePosScreen> createState() => _EmployeePosScreenState();
}

class _EmployeePosScreenState extends ConsumerState<EmployeePosScreen> {
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final List<CartItem> _cart = [];
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return products.where((p) => p.isActive && !p.isOutOfStock).toList();
    }
    return products.where((p) {
      if (!p.isActive || p.isOutOfStock) return false;
      return p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _lookupBarcode(String storeOwnerId) async {
    final code = _barcodeController.text.trim();
    if (code.isEmpty) return;

    final product = await ref.read(productRepositoryProvider).getProductByBarcode(code, storeOwnerId);
    if (!mounted) return;

    if (product == null) {
      CredSnackBar.show(context, 'No product found for barcode', isError: true);
      return;
    }

    await _addProductToCart(product);
    _barcodeController.clear();
  }

  Future<void> _addProductToCart(Product product) async {
    if (product.bulkOptions.isEmpty) {
      setState(() {
        final existing = _cart.indexWhere(
          (c) =>
              c.product.id == product.id &&
              c.pricingOption == 'piece' &&
              c.bulkOption == null,
        );
        if (existing >= 0) {
          _cart[existing].quantity += 1;
        } else {
          _cart.add(CartItem(product: product));
        }
      });
      return;
    }

    final item = await showDialog<CartItem>(
      context: context,
      builder: (ctx) => _AddToCartDialog(product: product),
    );

    if (item != null) {
      setState(() {
        final existing = _cart.indexWhere(
          (c) =>
              c.product.id == item.product.id &&
              c.pricingOption == item.pricingOption &&
              c.bulkOption?.label == item.bulkOption?.label,
        );
        if (existing >= 0) {
          _cart[existing].quantity += item.quantity;
        } else {
          _cart.add(item);
        }
      });
    }
  }

  Future<void> _checkout(UserProfile profile, String storeOwnerId) async {
    if (_cart.isEmpty) return;

    final result = await CheckoutSheet.show(context, items: _cart);
    if (!mounted || result == null) return;

    // Sync any qty/remove edits from the sheet back into the live cart.
    setState(() {
      _cart
        ..clear()
        ..addAll(result.items);
    });
    if (_cart.isEmpty) return;

    final items = List<CartItem>.from(_cart);
    if (result.type == CheckoutType.cash) {
      await _completeCashSale(profile, storeOwnerId, items);
    } else {
      await _startDebtSale(profile, storeOwnerId, items);
    }
  }

  Future<void> _completeCashSale(
    UserProfile profile,
    String storeOwnerId,
    List<CartItem> items,
  ) async {
    final total = items.fold<double>(0, (acc, item) => acc + item.subtotal);
    final saleId = FirebaseFirestore.instance.collection('cash_products').doc().id;

    try {
      await ref.read(productRepositoryProvider).completeCashSale(
            saleId: saleId,
            storeOwnerId: storeOwnerId,
            employeeId: profile.id,
            items: items,
            total: total,
            amountPaid: total,
          );

      ref.invalidate(currentStoreProductsProvider);
      ref.invalidate(currentStoreSalesProvider);
      ref.invalidate(currentStoreTodayActivityProvider);

      if (!mounted) return;
      setState(() => _cart.clear());
      await _showReceipt(
        SaleRecord(
          id: saleId,
          type: SaleType.cash,
          total: total,
          storeOwnerId: storeOwnerId,
          employeeId: profile.id,
          items: items.map((i) => i.toSaleLineItem()).toList(),
          createdAt: DateTime.now(),
        ),
        profile,
      );
      if (!mounted) return;
      CredSnackBar.show(context, 'Cash sale completed');
    } catch (e) {
      if (mounted) {
        CredSnackBar.show(context, '$e', isError: true);
      }
      rethrow;
    }
  }

  Future<void> _startDebtSale(
    UserProfile profile,
    String storeOwnerId,
    List<CartItem> items,
  ) async {
    final customers = await ref.read(customerRepositoryProvider).searchCustomersByStore(storeOwnerId);
    if (!mounted) return;

    final customerProfiles = customers
        .map(
          (u) => CustomerProfile(
            customerId: u.id,
            fullName: u.fullName,
            email: u.email,
            phoneNumber: u.phoneNumber,
            province: u.province,
            municipality: u.municipality,
            barangay: u.barangay,
          ),
        )
        .toList();

    final customer = await CustomerPickerSheet.show(
      context,
      customers: customerProfiles,
      onRegisterNew: () => _registerDebtCustomer(profile, storeOwnerId, items),
    );
    if (!mounted || customer == null) return;

    await _confirmDebtSale(
      profile: profile,
      storeOwnerId: storeOwnerId,
      items: items,
      customer: customer,
    );
  }

  Future<void> _registerDebtCustomer(
    UserProfile profile,
    String storeOwnerId,
    List<CartItem> items,
  ) async {
    final store = await ref.read(storeRepositoryProvider).getStore(storeOwnerId);
    if (!mounted) return;
    final province = store?.province ?? profile.province;

    final data = await DebtCustomerRegisterSheet.show(context);
    if (data == null || !mounted) return;

    await ref.read(debtCustomerRepositoryProvider).registerDebtCustomer(
          storeOwnerId: storeOwnerId,
          storeOwnerProvince: province,
          customerData: DebtCustomerRegistrationData(
            fullName: data.fullName,
            phoneNumber: data.phone ?? '',
            municipality: data.municipality ?? '',
            barangay: data.barangay ?? '',
            email: data.email,
          ),
        );

    final customers = await ref.read(customerRepositoryProvider).searchCustomersByStore(storeOwnerId);
    UserProfile? match;
    for (final c in customers) {
      if (c.email == data.email || c.fullName == data.fullName) {
        match = c;
        break;
      }
    }

    if (match != null && mounted) {
      await _confirmDebtSale(
        profile: profile,
        storeOwnerId: storeOwnerId,
        items: items,
        customer: CustomerProfile(
          customerId: match.id,
          fullName: match.fullName,
          email: match.email,
          phoneNumber: match.phoneNumber,
        ),
      );
    }
  }

  Future<void> _confirmDebtSale({
    required UserProfile profile,
    required String storeOwnerId,
    required List<CartItem> items,
    required CustomerProfile customer,
  }) async {
    final total = items.fold<double>(0, (acc, item) => acc + item.subtotal);
    final payment = await showModalBottomSheet<_DebtPaymentDetails>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DebtPaymentSheet(total: total),
    );

    if (payment == null) return;

    final saleId = FirebaseFirestore.instance.collection('debt_products').doc().id;
    final remaining = (total - payment.initialPayment).clamp(0, total).toDouble();

    try {
      await ref.read(productRepositoryProvider).completeDebtSale(
            saleId: saleId,
            storeOwnerId: storeOwnerId,
            employeeId: profile.id,
            customerId: customer.customerId,
            items: items,
            total: total,
            remainingBalance: remaining,
            initialPayment: payment.initialPayment,
            dueDate: payment.dueDate,
            customerName: customer.fullName,
            customerPhone: customer.phoneNumber?.trim().isNotEmpty == true
                ? customer.phoneNumber!.trim()
                : null,
          );

      ref.invalidate(currentStoreProductsProvider);
      ref.invalidate(currentStoreSalesProvider);
      ref.invalidate(currentStoreDebtsProvider);
      ref.invalidate(currentStoreTodayActivityProvider);

      if (!mounted) return;
      setState(() => _cart.clear());

      await _showReceipt(
        SaleRecord(
          id: saleId,
          type: SaleType.debt,
          total: total,
          storeOwnerId: storeOwnerId,
          employeeId: profile.id,
          customerId: customer.customerId,
          customerName: customer.fullName,
          status: remaining <= 0 ? 'paid' : 'pending',
          paymentStatus: remaining <= 0
              ? 'paid'
              : payment.initialPayment > 0
                  ? 'partially_paid'
                  : 'unpaid',
          remainingBalance: remaining,
          items: items.map((i) => i.toSaleLineItem()).toList(),
          createdAt: DateTime.now(),
        ),
        profile,
      );
      if (!mounted) return;
      CredSnackBar.show(context, 'Debt sale completed');
    } catch (e) {
      if (mounted) {
        CredSnackBar.show(context, '$e', isError: true);
      }
      rethrow;
    }
  }

  Future<void> _showReceipt(SaleRecord sale, UserProfile profile) async {
    final storeOwnerId = resolveStoreOwnerId(profile);
    final storeInfo = await ref.read(receiptStoreInfoProvider(storeOwnerId).future);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Receipt',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptView(
              sale: sale,
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
              employeeName: profile.fullName,
            ),
            PdfExportButton(
              sale: sale,
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
              employeeName: profile.fullName,
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CredTheme.spaceMd,
                CredTheme.spaceMd,
                CredTheme.spaceMd,
                CredTheme.spaceXs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Retail Sales', style: CredTheme.pageTitle(context)),
                  Text(
                    'Search or scan products — review the cart at checkout',
                    style: CredTheme.bodyMutedStyle(context),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  CredSearchField(
                    controller: _searchController,
                    hint: 'Search products…',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  BarcodeInputCard(
                    controller: _barcodeController,
                    onSubmit: () => _lookupBarcode(storeOwnerId),
                    onScan: () async {
                      final code = await scanBarcode(context);
                      if (code != null) {
                        _barcodeController.text = code;
                        await _lookupBarcode(storeOwnerId);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CredAsyncView<List<Product>>(
                asyncValue: productsAsync,
                emptyMessage: 'No products available',
                onRetry: () => ref.invalidate(currentStoreProductsProvider),
                builder: (products) {
                  final filtered = _filterProducts(products);
                  if (filtered.isEmpty) {
                    return const EmptyState(message: 'No matching products');
                  }
                  return CredProductGrid(
                    products: filtered,
                    padding: const EdgeInsets.fromLTRB(
                      CredTheme.spaceMd,
                      CredTheme.spaceXs,
                      CredTheme.spaceMd,
                      CredTheme.spaceSm,
                    ),
                    itemBuilder: (context, product, _) => CredProductCard(
                      product: product,
                      onTap: () => _addProductToCart(product),
                    ),
                  );
                },
              ),
            ),
            SaleCartSummaryBar(
              items: _cart,
              onCheckout: _cart.isEmpty ? null : () => _checkout(profile, storeOwnerId),
            ),
          ],
        );
      },
    );
  }
}

class _AddToCartDialog extends StatefulWidget {
  const _AddToCartDialog({required this.product});

  final Product product;

  @override
  State<_AddToCartDialog> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends State<_AddToCartDialog> {
  String _pricingOption = 'piece';
  BulkOption? _bulkOption;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.bulkOptions.isNotEmpty) {
      _bulkOption = widget.product.bulkOptions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return AlertDialog(
      title: Text(product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'piece', label: Text('Piece')),
              if (product.bulkOptions.isNotEmpty)
                const ButtonSegment(value: 'bulk', label: Text('Bulk')),
            ],
            selected: {_pricingOption},
            onSelectionChanged: (s) => setState(() {
              _pricingOption = s.first;
              if (_pricingOption == 'bulk' && product.bulkOptions.isNotEmpty) {
                _bulkOption = product.bulkOptions.first;
              }
            }),
          ),
          if (_pricingOption == 'bulk' && product.bulkOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<BulkOption>(
              initialValue: _bulkOption,
              decoration: const InputDecoration(labelText: 'Bulk option'),
              items: product.bulkOptions
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text('${b.label} (${b.piecesPerBulk} pcs)'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _bulkOption = v),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Text(
            'Subtotal: ${CurrencyFormatter.format(_unitPrice * _quantity)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              CartItem(
                product: product,
                quantity: _quantity,
                pricingOption: _pricingOption,
                bulkOption: _pricingOption == 'bulk' ? _bulkOption : null,
              ),
            );
          },
          child: const Text('Add to Cart'),
        ),
      ],
    );
  }

  double get _unitPrice {
    if (_pricingOption == 'bulk' && _bulkOption != null) {
      return _bulkOption!.price;
    }
    return widget.product.sellingPrice;
  }
}

class _DebtPaymentDetails {
  const _DebtPaymentDetails({
    required this.initialPayment,
    required this.dueDate,
  });

  final double initialPayment;
  final DateTime dueDate;
}

class _DebtPaymentSheet extends StatefulWidget {
  const _DebtPaymentSheet({required this.total});

  final double total;

  @override
  State<_DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends State<_DebtPaymentSheet> {
  final _paymentController = TextEditingController();
  int _dueDays = 15;

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPayment = double.tryParse(_paymentController.text) ?? 0;
    final remaining = (widget.total - initialPayment).clamp(0, widget.total);

    return CredSheetScaffold(
      title: 'Debt Payment',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total: ${CurrencyFormatter.format(widget.total)}'),
          const SizedBox(height: CredTheme.spaceMd),
          TextField(
            controller: _paymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Initial Payment (optional)',
              prefixText: '₱ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CredTheme.spaceSm),
          Text('Remaining: ${CurrencyFormatter.format(remaining.toDouble())}'),
          const SizedBox(height: CredTheme.spaceMd),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 15, label: Text('15 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
            ],
            selected: {_dueDays},
            onSelectionChanged: (s) => setState(() => _dueDays = s.first),
          ),
          const SizedBox(height: CredTheme.spaceMd),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _DebtPaymentDetails(
                  initialPayment: initialPayment,
                  dueDate: DateTime.now().add(Duration(days: _dueDays)),
                ),
              );
            },
            child: const Text('Complete Debt Sale'),
          ),
        ],
      ),
    );
  }
}
