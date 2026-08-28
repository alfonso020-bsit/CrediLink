import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/calendar/debt_calendar.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_profile_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';

class EmployeeDashboardTab extends ConsumerWidget {
  const EmployeeDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (profile) {
        if (profile == null) return const EmptyState(message: 'No profile');

        return CredTabPageLayout(
          onRefresh: () => _refresh(ref),
          children: [
            CredProfileCard(
              fullName: profile.fullName,
              role: UserRole.employee,
              position: profile.position,
              storeName: profile.storeName,
              imageUrl: profile.profileImage,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: "Today's Activity",
              child: _TodayStatsSection(),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Debt Summary',
              child: _DebtSummarySection(),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Debt Calendar',
              child: _DebtCalendarSection(),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Quick Links',
              child: _QuickLinksSection(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentStoreTodayActivityProvider);
    ref.invalidate(currentStoreDebtsProvider);
    ref.invalidate(currentStoreProductsProvider);
    await Future.wait([
      ref.read(currentStoreTodayActivityProvider.future),
      ref.read(currentStoreDebtsProvider.future),
      ref.read(currentStoreProductsProvider.future),
    ]);
  }
}

class _TodayStatsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(currentStoreTodayActivityProvider);

    return CredAsyncView<Map<String, int>>(
      asyncValue: activity,
      builder: (stats) => CredMetricGrid(
        metrics: [
          CredMetricCard(
            label: 'Cash Sales Today',
            value: '${stats['transactions'] ?? 0}',
            icon: Icons.point_of_sale,
            accentColor: CredTheme.success,
          ),
          CredMetricCard(
            label: 'New Debts Today',
            value: '${stats['newDebts'] ?? 0}',
            icon: Icons.receipt_long,
            accentColor: CredTheme.info,
          ),
          CredMetricCard(
            label: 'Payments Today',
            value: '${stats['payments'] ?? 0}',
            icon: Icons.payments,
            accentColor: CredTheme.primary,
          ),
          CredMetricCard(
            label: 'Low Stock Items',
            value: '${_lowStockCount(ref)}',
            icon: Icons.warning_amber,
            accentColor: CredTheme.warning,
          ),
        ],
      ),
    );
  }

  int _lowStockCount(WidgetRef ref) {
    final products = ref.watch(currentStoreProductsProvider).value ?? [];
    return products.where((p) => p.isActive && p.isLowStock).length;
  }
}

class _DebtSummarySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(currentStoreDebtsProvider);

    return CredAsyncView<List<DebtRecord>>(
      asyncValue: debts,
      builder: (items) {
        final outstanding = items.fold<double>(0, (s, d) => s + d.remainingBalance);
        final overdue = items.where((d) => d.isOverdue && !d.isPaid).length;
        final pending = items.where((d) => !d.isPaid).length;

        return CredMetricGrid(
          metrics: [
            CredMetricCard(
              label: 'Outstanding',
              value: CurrencyFormatter.format(outstanding),
              icon: Icons.account_balance_wallet,
              accentColor: CredTheme.danger,
            ),
            CredMetricCard(
              label: 'Pending / Overdue',
              value: '$pending / $overdue',
              icon: Icons.schedule,
              accentColor: CredTheme.warning,
            ),
          ],
        );
      },
    );
  }
}

class _DebtCalendarSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(currentStoreDebtsProvider);

    return CredAsyncView<List<DebtRecord>>(
      asyncValue: debts,
      emptyMessage: 'No debts',
      builder: (items) => DebtCalendar(
        debts: items,
        onDebtTap: (debt) => DebtReceiptSheet.show(context, debt),
      ),
    );
  }
}

class _QuickLinksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Retail Sales (POS)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/employee/tab3'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Products Inventory'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/employee/tab4'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Reports'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/employee/tab5'),
          ),
        ],
      ),
    );
  }
}
