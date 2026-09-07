import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../customer_helpers.dart';

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
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final bundleAsync = ref.watch(currentCustomerDebtsBundleProvider);

    return CredAsyncView<
        ({
          List<DebtRecord> debts,
          Map<String, StoreProfile> stores,
          Map<String, String> storePhones,
        })>(
      asyncValue: bundleAsync,
      emptyMessage: 'No debts',
      onRetry: () => _invalidateBundle(),
      builder: (bundle) {
        if (bundle.debts.isEmpty) {
          return const EmptyState(
            title: 'No debts',
            message: 'No debts',
          );
        }

        final sortedDebts = [...bundle.debts]
          ..sort((a, b) {
            final aOverdue = paymentRepo.isDebtOverdue(a);
            final bOverdue = paymentRepo.isDebtOverdue(b);
            if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
            final ad = a.dueDate ?? DateTime(2100);
            final bd = b.dueDate ?? DateTime(2100);
            return ad.compareTo(bd);
          });

        final debts = _filterDebts(
          sortedDebts,
          paymentRepo,
          stores: bundle.stores,
        );
        final grouped = CustomerHelpers.groupDebtsByStore(debts);
        final outstanding = debts
            .where((d) => !d.isPaid)
            .fold<double>(0, (sum, d) => sum + d.remainingBalance);

        return CredTabPageLayout(
          onRefresh: () async {
            _invalidateBundle();
            await ref.read(currentCustomerDebtsBundleProvider.future);
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
            CredSection(
              title: 'Summary',
              child: CredMetricCard(
                label: 'Total Outstanding',
                value: CurrencyFormatter.format(outstanding),
                icon: Icons.account_balance_wallet,
                accentColor: CredTheme.danger,
                style: CredMetricStyle.featured,
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            if (debts.isEmpty)
              const EmptyState(
                title: 'No matches',
                message: 'No debts match your filters',
              )
            else
              CredSection(
                title: 'By store',
                subtitle:
                    '${debts.length} debt${debts.length == 1 ? '' : 's'} · ${grouped.length} store${grouped.length == 1 ? '' : 's'}',
                child: Column(
                  children: [
                    for (final entry in grouped.entries) ...[
                      _StoreDebtSection(
                        storeName: bundle.stores[entry.key]?.displayName ?? 'Store',
                        storeLocation: bundle.stores[entry.key] != null
                            ? CustomerHelpers.storeLocation(bundle.stores[entry.key]!)
                            : '',
                        storeImage: bundle.stores[entry.key]?.storeImage,
                        storePhone: bundle.storePhones[entry.key],
                        debts: entry.value,
                        paymentRepo: paymentRepo,
                      ),
                      const SizedBox(height: CredTheme.spaceMd),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _invalidateBundle() {
    final profile = ref.read(currentProfileProvider).value;
    if (profile != null) {
      ref.invalidate(customerDebtsProvider(profile.id));
    }
    ref.invalidate(currentCustomerDebtsBundleProvider);
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

  List<DebtRecord> _filterDebts(
    List<DebtRecord> debts,
    PaymentRepository paymentRepo, {
    Map<String, StoreProfile> stores = const {},
  }) {
    final term = _searchController.text.trim().toLowerCase();
    return debts.where((debt) {
      final store = stores[debt.storeOwnerId];
      final matchesSearch = term.isEmpty ||
          (store?.displayName.toLowerCase().contains(term) ?? false) ||
          (store != null && CustomerHelpers.storeLocation(store).toLowerCase().contains(term)) ||
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
}

class _StoreDebtSection extends StatelessWidget {
  const _StoreDebtSection({
    required this.storeName,
    required this.storeLocation,
    required this.debts,
    required this.paymentRepo,
    this.storeImage,
    this.storePhone,
  });

  final String storeName;
  final String storeLocation;
  final List<DebtRecord> debts;
  final PaymentRepository paymentRepo;
  final String? storeImage;
  final String? storePhone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CredSurfaceTile(
          leading: CredAvatar(name: storeName, imageUrl: storeImage),
          title: Text(storeName, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: storeLocation.isNotEmpty
              ? Text(storeLocation, maxLines: 2, overflow: TextOverflow.ellipsis)
              : Text('${debts.length} debt${debts.length == 1 ? '' : 's'}'),
          trailing: Text(
            '${debts.length}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CredTheme.primary,
                ),
          ),
        ),
        const SizedBox(height: CredTheme.spaceXs),
        for (var i = 0; i < debts.length; i++) ...[
          if (i > 0) const SizedBox(height: CredTheme.spaceXs),
          _DebtRow(
            debt: debts[i],
            paymentRepo: paymentRepo,
            storeName: storeName,
            storePhone: storePhone,
          ),
        ],
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.debt,
    required this.paymentRepo,
    required this.storeName,
    this.storePhone,
  });

  final DebtRecord debt;
  final PaymentRepository paymentRepo;
  final String storeName;
  final String? storePhone;

  @override
  Widget build(BuildContext context) {
    final overdue = paymentRepo.isDebtOverdue(debt);

    return CredSurfaceTile(
      emphasized: overdue,
      leading: Icon(
        debt.isPaid ? Icons.check_circle : Icons.receipt_long,
        color: debt.isPaid
            ? CredTheme.success
            : overdue
                ? CredTheme.danger
                : CredTheme.warning,
      ),
      title: Text(
        'Txn ${debt.id?.substring(0, 8) ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        debt.dueDate != null
            ? 'Due ${DateFormatter.format(debt.dueDate!)}'
            : 'Created ${debt.createdAt != null ? DateFormatter.format(debt.createdAt!) : ''}',
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(debt.remainingBalance),
            style: CredTheme.listAmountStyle(context),
          ),
          const SizedBox(height: 4),
          CredStatusChip.debt(
            paymentStatus: debt.paymentStatus,
            isOverdue: overdue,
            compact: true,
          ),
        ],
      ),
      onTap: () => DebtReceiptSheet.show(
        context,
        debt,
        storeName: storeName,
        storePhone: storePhone,
      ),
    );
  }
}
