import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/settings/profile_settings_sheet.dart';
import '../customer_helpers.dart';

class CustomerAccountTab extends ConsumerWidget {
  const CustomerAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            await ref.read(currentProfileProvider.future);
          },
          child: FutureBuilder<_AccountData>(
            future: _loadAccountData(ref, p),
            builder: (context, snap) {
              if (!snap.hasData) {
                return ListView(
                  children: const [
                    SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  ],
                );
              }
              final data = snap.data!;
              return ListView(
                padding: CredTheme.pagePadding,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(CredTheme.spaceMd),
                      child: Row(
                        children: [
                          CredAvatar(name: p.fullName, size: 72),
                          const SizedBox(width: CredTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${p.fullName}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(CustomerHelpers.fullAddress(p)),
                                if (p.phoneNumber != null) Text(p.phoneNumber!),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Profile settings',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => ProfileSettingsSheet.show(context, p),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  CredMetricGrid(
                    metrics: [
                      CredMetricCard(
                        label: 'Outstanding',
                        value: CurrencyFormatter.format(data.outstanding),
                        icon: Icons.account_balance_wallet,
                        accentColor: CredTheme.primary,
                      ),
                      CredMetricCard(
                        label: 'Active Debts',
                        value: '${data.activeDebts}',
                        icon: Icons.receipt_long,
                        accentColor: CredTheme.warning,
                      ),
                      CredMetricCard(
                        label: 'Overdue',
                        value: '${data.overdueCount}',
                        icon: Icons.warning_amber,
                        accentColor: CredTheme.danger,
                      ),
                      CredMetricCard(
                        label: 'Transactions',
                        value: '${data.transactionCount}',
                        icon: Icons.history,
                        accentColor: CredTheme.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: CredTheme.spaceLg),
                  CredSection(
                    title: 'Quick Links',
                    child: Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.money),
                            title: const Text('My Debts'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/customer/tab2'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Transaction History'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/customer/tab3'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.notifications),
                            title: const Text('Financial Alerts'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/customer/tab5'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceLg),
                  CredSection(
                    title: 'Recent Debts',
                    child: data.recentDebts.isEmpty
                        ? const EmptyState(message: 'No recent debts')
                        : Column(
                            children: data.recentDebts
                                .map((debt) => _RecentDebtTile(debt: debt))
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }

  Future<_AccountData> _loadAccountData(WidgetRef ref, UserProfile profile) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final productRepo = ref.read(productRepositoryProvider);

    final debts = await paymentRepo.getDebtsByCustomer(profile.id);
    final sales = await productRepo.getSalesByCustomer(
      profile.id,
      customerName: profile.fullName,
    );

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

    return _AccountData(
      outstanding: outstanding,
      activeDebts: activeDebts,
      overdueCount: overdueCount,
      transactionCount: sales.length,
      recentDebts: recentDebts.take(5).toList(),
    );
  }
}

class _AccountData {
  const _AccountData({
    required this.outstanding,
    required this.activeDebts,
    required this.overdueCount,
    required this.transactionCount,
    required this.recentDebts,
  });

  final double outstanding;
  final int activeDebts;
  final int overdueCount;
  final int transactionCount;
  final List<DebtRecord> recentDebts;
}

class _RecentDebtTile extends ConsumerWidget {
  const _RecentDebtTile({required this.debt});

  final DebtRecord debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final overdue = paymentRepo.isDebtOverdue(debt);
    final cred = CredThemeExtension.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: CredTheme.spaceXs),
      color: overdue ? cred.danger.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: Icon(
          overdue ? Icons.warning : Icons.receipt,
          color: overdue ? cred.danger : null,
        ),
        title: Text(debt.customerName ?? 'Debt'),
        subtitle: Text(
          debt.dueDate != null
              ? 'Due ${DateFormatter.format(debt.dueDate!)}'
              : debt.createdAt != null
                  ? DateFormatter.format(debt.createdAt!)
                  : '',
        ),
        trailing: Text(CurrencyFormatter.format(debt.remainingBalance)),
        onTap: () => DebtReceiptSheet.show(context, debt),
      ),
    );
  }
}
