import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';
import '../customer_helpers.dart';

class CustomerHistoryTab extends ConsumerStatefulWidget {
  const CustomerHistoryTab({super.key});

  @override
  ConsumerState<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends ConsumerState<CustomerHistoryTab> {
  String _typeFilter = 'all';
  String _dateFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        return FutureBuilder<({List<SaleRecord> sales, Map<String, StoreProfile> stores})>(
          future: _loadHistory(ref, p.id, p.fullName),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final filtered = _filterSales(snap.data!.sales);

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: CredTheme.pagePadding,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search transactions...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
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
                    const EmptyState(message: 'No transaction history')
                  else
                    ...filtered.map((sale) {
                      final store = snap.data!.stores[sale.storeOwnerId];
                      final storeName = store?.storeName ?? 'Store';
                      return Card(
                        margin: const EdgeInsets.only(bottom: CredTheme.spaceXs),
                        child: ListTile(
                          leading: CredAvatar(name: storeName),
                          title: Text(storeName),
                          subtitle: Text(
                            '${CustomerHelpers.saleTypeLabel(sale)} • ${sale.createdAt != null ? DateFormatter.formatDateTime(sale.createdAt!) : ''}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(CurrencyFormatter.format(sale.total)),
                              Chip(
                                label: Text(
                                  CustomerHelpers.saleTypeLabel(sale),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
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
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }

  Widget _typeChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: CredTheme.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: _typeFilter == value,
        onSelected: (_) => setState(() => _typeFilter = value),
      ),
    );
  }

  Widget _dateChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: CredTheme.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: _dateFilter == value,
        onSelected: (_) => setState(() => _dateFilter = value),
      ),
    );
  }

  List<SaleRecord> _filterSales(List<SaleRecord> sales) {
    final term = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return sales.where((sale) {
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
          CurrencyFormatter.format(sale.total).toLowerCase().contains(term);

      return matchesType && matchesDate && matchesSearch;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<({List<SaleRecord> sales, Map<String, StoreProfile> stores})> _loadHistory(
    WidgetRef ref,
    String customerId,
    String customerName,
  ) async {
    final productRepo = ref.read(productRepositoryProvider);
    final storeRepo = ref.read(storeRepositoryProvider);
    final sales = await productRepo.getSalesByCustomer(customerId, customerName: customerName);

    final storeIds = sales.map((s) => s.storeOwnerId).toSet();
    final stores = <String, StoreProfile>{};
    for (final id in storeIds) {
      final store = await storeRepo.getStore(id);
      if (store != null) stores[id] = store;
    }

    return (sales: sales, stores: stores);
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
