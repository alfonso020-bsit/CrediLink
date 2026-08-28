import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../customer_helpers.dart';
import '../widgets/debt_status_badge.dart';

class CustomerDebtsTab extends ConsumerStatefulWidget {
  const CustomerDebtsTab({super.key});

  @override
  ConsumerState<CustomerDebtsTab> createState() => _CustomerDebtsTabState();
}

class _CustomerDebtsTabState extends ConsumerState<CustomerDebtsTab> {
  String _statusFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);

    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        return FutureBuilder<
            ({
              List<DebtRecord> debts,
              Map<String, StoreProfile> stores,
              Map<String, String> storePhones,
            })>(
          future: _loadDebts(ref, p.id),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final debts = _filterDebts(snap.data!.debts, paymentRepo);
            final grouped = CustomerHelpers.groupDebtsByStore(debts);
            final outstanding = debts
                .where((d) => !d.isPaid)
                .fold<double>(0, (sum, d) => sum + d.remainingBalance);

            if (snap.data!.debts.isEmpty) {
              return const EmptyState(message: 'No debts');
            }

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: CredTheme.pagePadding,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search stores or amounts...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'All'),
                        _filterChip('unpaid', 'Unpaid'),
                        _filterChip('partially_paid', 'Partial'),
                        _filterChip('paid', 'Paid'),
                        _filterChip('overdue', 'Overdue'),
                      ],
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  CredMetricCard(
                    label: 'Total Outstanding',
                    value: CurrencyFormatter.format(outstanding),
                    icon: Icons.account_balance_wallet,
                    accentColor: CredTheme.primary,
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  ...grouped.entries.map((entry) {
                    final store = snap.data!.stores[entry.key];
                    final storeName = store?.storeName ?? 'Store';
                    final storePhone = snap.data!.storePhones[entry.key];
                    return _StoreDebtSection(
                      storeName: storeName,
                      storeLocation: store != null ? CustomerHelpers.storeLocation(store) : '',
                      storePhone: storePhone,
                      debts: entry.value,
                      paymentRepo: paymentRepo,
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

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: CredTheme.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }

  List<DebtRecord> _filterDebts(List<DebtRecord> debts, PaymentRepository paymentRepo) {
    final term = _searchController.text.trim().toLowerCase();
    return debts.where((debt) {
      final matchesSearch = term.isEmpty ||
          debt.storeOwnerId.toLowerCase().contains(term) ||
          (debt.customerName?.toLowerCase().contains(term) ?? false) ||
          CurrencyFormatter.format(debt.remainingBalance).toLowerCase().contains(term);

      final matchesStatus = switch (_statusFilter) {
        'overdue' => paymentRepo.isDebtOverdue(debt),
        'all' => true,
        _ => debt.paymentStatus == _statusFilter,
      };

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<
      ({
        List<DebtRecord> debts,
        Map<String, StoreProfile> stores,
        Map<String, String> storePhones,
      })> _loadDebts(
    WidgetRef ref,
    String customerId,
  ) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final storeRepo = ref.read(storeRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final debts = await paymentRepo.getDebtsByCustomer(customerId);

    final storeIds = debts.map((d) => d.storeOwnerId).toSet();
    final stores = <String, StoreProfile>{};
    for (final id in storeIds) {
      final store = await storeRepo.getStore(id);
      if (store != null) stores[id] = store;
    }
    final storePhones = await CustomerHelpers.loadStorePhones(authRepo, storeIds);

    debts.sort((a, b) {
      final aOverdue = paymentRepo.isDebtOverdue(a);
      final bOverdue = paymentRepo.isDebtOverdue(b);
      if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
      final ad = a.dueDate ?? DateTime(2100);
      final bd = b.dueDate ?? DateTime(2100);
      return ad.compareTo(bd);
    });

    return (debts: debts, stores: stores, storePhones: storePhones);
  }
}

class _StoreDebtSection extends StatelessWidget {
  const _StoreDebtSection({
    required this.storeName,
    required this.storeLocation,
    required this.debts,
    required this.paymentRepo,
    this.storePhone,
  });

  final String storeName;
  final String storeLocation;
  final List<DebtRecord> debts;
  final PaymentRepository paymentRepo;
  final String? storePhone;

  @override
  Widget build(BuildContext context) {
    final cred = CredThemeExtension.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: CredTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CredAvatar(name: storeName),
            title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: storeLocation.isNotEmpty ? Text(storeLocation) : null,
            trailing: Text('${debts.length} debt${debts.length == 1 ? '' : 's'}'),
          ),
          const Divider(height: 1),
          ...debts.map((debt) {
            final overdue = paymentRepo.isDebtOverdue(debt);
            return ListTile(
              title: Text('Transaction ${debt.id?.substring(0, 8) ?? ''}'),
              subtitle: Text(
                debt.dueDate != null
                    ? 'Due ${DateFormatter.format(debt.dueDate!)}'
                    : 'Created ${debt.createdAt != null ? DateFormatter.format(debt.createdAt!) : ''}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(debt.remainingBalance)),
                  const SizedBox(height: 4),
                  DebtStatusBadge(debt: debt, paymentRepo: paymentRepo),
                ],
              ),
              tileColor: overdue ? cred.danger.withValues(alpha: 0.08) : null,
              onTap: () => DebtReceiptSheet.show(
                context,
                debt,
                storeName: storeName,
                storePhone: storePhone,
              ),
            );
          }),
        ],
      ),
    );
  }
}
