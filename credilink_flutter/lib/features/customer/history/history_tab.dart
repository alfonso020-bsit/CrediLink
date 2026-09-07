import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';

class CustomerHistoryTab extends ConsumerStatefulWidget {
  const CustomerHistoryTab({super.key});

  @override
  ConsumerState<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends ConsumerState<CustomerHistoryTab> {
  static const _pageSize = 20;

  String _typeFilter = 'all';
  String _dateFilter = 'all';
  int _visibleCount = _pageSize;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(currentCustomerHistoryBundleProvider);

    return CredAsyncView<
        ({
          List<SaleRecord> sales,
          Map<String, StoreProfile> stores,
        })>(
      asyncValue: bundleAsync,
      emptyMessage: 'No transaction history',
      onRetry: () => _invalidateBundle(),
      builder: (bundle) {
        final stores = bundle.stores;
        final filtered = _filterSales(bundle.sales, stores);
        final visible = filtered.take(_visibleCount).toList();
        final hasMore = filtered.length > visible.length;

        return CredTabPageLayout(
          onRefresh: () async {
            setState(() => _visibleCount = _pageSize);
            _invalidateBundle();
            await ref.read(currentCustomerHistoryBundleProvider.future);
          },
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search stores or amounts...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {
                _visibleCount = _pageSize;
              }),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _typeChip('all', 'All'),
                  _typeChip('cash', 'Cash'),
                  _typeChip('debt', 'Credit'),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceXs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _dateChip('all', 'All Time'),
                  _dateChip('today', 'Today'),
                  _dateChip('week', 'This Week'),
                  _dateChip('month', 'This Month'),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            if (filtered.isEmpty)
              const EmptyState(
                title: 'No history',
                message: 'No transaction history',
              )
            else ...[
              Text(
                'Showing ${visible.length} of ${filtered.length}',
                style: CredTheme.bodyMutedStyle(context),
              ),
              const SizedBox(height: CredTheme.spaceSm),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                Builder(
                  builder: (context) {
                    final sale = visible[i];
                    final store = stores[sale.storeOwnerId];
                    final storeName = store?.displayName ?? 'Store';
                    final isCash = sale.type == SaleType.cash;
                    return CredSurfaceTile(
                      leading: CredAvatar(
                        name: storeName,
                        imageUrl: store?.storeImage,
                      ),
                      title: Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        sale.createdAt != null
                            ? DateFormatter.formatDateTime(sale.createdAt!)
                            : '',
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(sale.total),
                            style: CredTheme.listAmountStyle(context),
                          ),
                          const SizedBox(height: 4),
                          CredStatusChip.saleType(isCash: isCash, compact: true),
                        ],
                      ),
                      onTap: () {
                        if (sale.type == SaleType.debt) {
                          final debt = _saleToDebt(sale);
                          DebtReceiptSheet.show(context, debt, storeName: storeName);
                        } else {
                          _showCashReceipt(context, sale, storeName);
                        }
                      },
                    );
                  },
                ),
              ],
              if (hasMore) ...[
                const SizedBox(height: CredTheme.spaceMd),
                OutlinedButton(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  child: Text('Load more (${filtered.length - visible.length} left)'),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  void _invalidateBundle() {
    ref.invalidate(currentCustomerSalesProvider);
    ref.invalidate(currentCustomerHistoryBundleProvider);
  }

  Widget _typeChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: CredTheme.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: _typeFilter == value,
        onSelected: (_) => setState(() {
          _typeFilter = value;
          _visibleCount = _pageSize;
        }),
      ),
    );
  }

  Widget _dateChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: CredTheme.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: _dateFilter == value,
        onSelected: (_) => setState(() {
          _dateFilter = value;
          _visibleCount = _pageSize;
        }),
      ),
    );
  }

  List<SaleRecord> _filterSales(
    List<SaleRecord> sales,
    Map<String, StoreProfile> stores,
  ) {
    final term = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return sales.where((sale) {
      final store = stores[sale.storeOwnerId];
      final matchesType = _typeFilter == 'all' ||
          (_typeFilter == 'cash' && sale.type == SaleType.cash) ||
          (_typeFilter == 'debt' && sale.type == SaleType.debt);

      final created = sale.createdAt;
      final matchesDate = switch (_dateFilter) {
        'today' => created != null && _isSameDay(created, now),
        'week' => created != null && now.difference(created).inDays <= 7,
        'month' => created != null &&
            created.year == now.year &&
            created.month == now.month,
        _ => true,
      };

      final matchesSearch = term.isEmpty ||
          sale.id.toLowerCase().contains(term) ||
          (store?.displayName.toLowerCase().contains(term) ?? false) ||
          CurrencyFormatter.format(sale.total).toLowerCase().contains(term);

      return matchesType && matchesDate && matchesSearch;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showCashReceipt(BuildContext context, SaleRecord sale, String storeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Receipt',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptView(sale: sale, storeName: storeName),
            const SizedBox(height: CredTheme.spaceSm),
            PdfExportButton(sale: sale, storeName: storeName),
          ],
        ),
      ),
    );
  }

  DebtRecord _saleToDebt(SaleRecord sale) {
    return DebtRecord(
      id: sale.id,
      customerId: sale.customerId ?? '',
      storeOwnerId: sale.storeOwnerId,
      totalAmount: sale.total,
      remainingBalance: sale.remainingBalance ?? sale.total,
      status: sale.status,
      paymentStatus: sale.paymentStatus ?? 'unpaid',
      customerName: sale.customerName,
      items: sale.items,
      createdAt: sale.createdAt,
    );
  }
}
