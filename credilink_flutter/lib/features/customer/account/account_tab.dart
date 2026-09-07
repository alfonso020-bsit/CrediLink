import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/store_profile.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_fade_in.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_profile_card.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/settings/profile_settings_sheet.dart';
import '../customer_helpers.dart';

class CustomerAccountTab extends ConsumerWidget {
  const CustomerAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      onRetry: () => ref.invalidate(currentProfileProvider),
      builder: (p) {
        if (p == null) return const EmptyState(message: 'No profile');

        final debtsAsync = ref.watch(currentCustomerDebtsProvider);
        final salesAsync = ref.watch(currentCustomerSalesProvider);
        final combined = _combineDebtsAndSales(debtsAsync, salesAsync);

        return CredAsyncView<({List<DebtRecord> debts, int transactionCount})>(
          asyncValue: combined,
          onRetry: () => _invalidateAccountData(ref, p.id),
          builder: (data) {
            final paymentRepo = ref.read(paymentRepositoryProvider);
            final debts = data.debts;
            final outstanding = debts
                .where((d) => !d.isPaid)
                .fold<double>(0, (sum, d) => sum + d.remainingBalance);
            final activeDebts = debts.where((d) => !d.isPaid).length;
            final overdueCount = debts.where((d) => paymentRepo.isDebtOverdue(d)).length;

            final recentDebts = [...debts]
              ..sort((a, b) {
                final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad);
              });
            final recent = recentDebts.take(5).toList();
            final stores = _storesForRecent(ref, recent);

            final address = CustomerHelpers.fullAddress(p);
            final subtitleParts = [
              if (address.trim().isNotEmpty) address,
              if (p.phoneNumber != null && p.phoneNumber!.trim().isNotEmpty) p.phoneNumber!,
            ];

            return CredTabPageLayout(
              onRefresh: () => _refresh(ref, p.id, recent),
              children: [
                CredProfileCard(
                  fullName: p.fullName,
                  role: UserRole.customer,
                  subtitle: subtitleParts.isEmpty ? null : subtitleParts.join('\n'),
                  imageUrl: p.profileImage,
                  onTap: () => ProfileSettingsSheet.show(context, p),
                ),
                const SizedBox(height: CredTheme.spaceLg),
                CredFadeIn(
                  child: CredSection(
                    title: 'Account summary',
                    subtitle: 'Your debts at a glance',
                    child: Column(
                      children: [
                        CredMetricCard(
                          label: 'Outstanding',
                          value: CurrencyFormatter.format(outstanding),
                          icon: Icons.account_balance_wallet,
                          accentColor: CredTheme.danger,
                          style: CredMetricStyle.featured,
                        ),
                        const SizedBox(height: CredTheme.spaceSm),
                        CredMetricGrid(
                          metrics: [
                            CredMetricCard(
                              label: 'Active Debts',
                              value: '$activeDebts',
                              icon: Icons.receipt_long,
                              accentColor: CredTheme.warning,
                              onTap: () => context.go('/customer/tab2'),
                            ),
                            CredMetricCard(
                              label: 'Overdue',
                              value: '$overdueCount',
                              icon: Icons.warning_amber,
                              accentColor: CredTheme.danger,
                              onTap: overdueCount > 0
                                  ? () => context.go('/customer/tab5')
                                  : null,
                            ),
                            CredMetricCard(
                              label: 'Transactions',
                              value: '${data.transactionCount}',
                              icon: Icons.history,
                              accentColor: CredTheme.info,
                              onTap: () => context.go('/customer/tab3'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CredTheme.spaceLg),
                CredSection(
                  title: 'Quick Actions',
                  child: CredQuickActionGrid(
                    actions: [
                      CredQuickAction(
                        label: 'My Debts',
                        icon: Icons.account_balance_wallet,
                        onPressed: () => context.go('/customer/tab2'),
                      ),
                      CredQuickAction(
                        label: 'History',
                        icon: Icons.history,
                        onPressed: () => context.go('/customer/tab3'),
                      ),
                      CredQuickAction(
                        label: 'Products',
                        icon: Icons.storefront,
                        onPressed: () => context.go('/customer/tab4'),
                      ),
                      CredQuickAction(
                        label: 'Alerts',
                        icon: Icons.notifications_outlined,
                        onPressed: () => context.go('/customer/tab5'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CredTheme.spaceLg),
                CredSection(
                  title: 'Recent Debts',
                  child: recent.isEmpty
                      ? EmptyState(
                          title: 'No recent debts',
                          message: 'Debts from your stores will appear here',
                          action: OutlinedButton(
                            onPressed: () => context.go('/customer/tab2'),
                            child: const Text('View my debts'),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                              _RecentDebtTile(
                                debt: recent[i],
                                store: stores[recent[i].storeOwnerId],
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static AsyncValue<({List<DebtRecord> debts, int transactionCount})> _combineDebtsAndSales(
    AsyncValue<List<DebtRecord>> debtsAsync,
    AsyncValue<List<SaleRecord>> salesAsync,
  ) {
    return debtsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
      data: (debts) => salesAsync.when(
        loading: () => const AsyncValue.loading(),
        error: AsyncValue.error,
        data: (sales) => AsyncValue.data((debts: debts, transactionCount: sales.length)),
      ),
    );
  }

  static Map<String, StoreProfile> _storesForRecent(WidgetRef ref, List<DebtRecord> recent) {
    final stores = <String, StoreProfile>{};
    for (final id in recent.map((d) => d.storeOwnerId).toSet()) {
      final store = ref.watch(storeProfileProvider(id)).value;
      if (store != null) stores[id] = store;
    }
    return stores;
  }

  static void _invalidateAccountData(WidgetRef ref, String customerId) {
    ref.invalidate(customerDebtsProvider(customerId));
    ref.invalidate(currentCustomerDebtsProvider);
    ref.invalidate(currentCustomerSalesProvider);
  }

  static Future<void> _refresh(
    WidgetRef ref,
    String customerId,
    List<DebtRecord> recent,
  ) async {
    ref.invalidate(currentProfileProvider);
    _invalidateAccountData(ref, customerId);
    for (final id in recent.map((d) => d.storeOwnerId).toSet()) {
      ref.invalidate(storeProfileProvider(id));
    }
    await Future.wait([
      ref.read(currentProfileProvider.future),
      ref.read(currentCustomerDebtsProvider.future),
      ref.read(currentCustomerSalesProvider.future),
    ]);
  }
}

class _RecentDebtTile extends ConsumerWidget {
  const _RecentDebtTile({required this.debt, this.store});

  final DebtRecord debt;
  final StoreProfile? store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final overdue = paymentRepo.isDebtOverdue(debt);
    final storeName = store?.displayName ?? 'Store';

    return CredSurfaceTile(
      emphasized: overdue,
      leading: CredAvatar(name: storeName, imageUrl: store?.storeImage),
      title: Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        debt.dueDate != null
            ? 'Due ${DateFormatter.format(debt.dueDate!)}'
            : debt.createdAt != null
                ? DateFormatter.format(debt.createdAt!)
                : '',
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
      ),
    );
  }
}
