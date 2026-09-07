import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/debt_record.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/calendar/debt_calendar.dart';
import '../../../shared/widgets/calendar/debt_day_sheet.dart';
import '../../../shared/widgets/charts/cred_line_trend_chart.dart';
import '../../../shared/widgets/charts/dashboard_sales_trend_section.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_fade_in.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_profile_card.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
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
        if (profile == null) {
          return const EmptyState(
            title: 'No profile',
            message: 'Unable to load your account.',
          );
        }
        final storeOwnerId = resolveStoreOwnerId(profile);
        final storeInfo = ref.watch(receiptStoreInfoProvider(storeOwnerId)).value;

        return CredTabPageLayout(
          onRefresh: () => _refresh(ref),
          children: [
            CredProfileCard(
              fullName: profile.fullName,
              role: UserRole.employee,
              position: profile.position,
              storeName: storeInfo?.name ?? profile.storeName,
              imageUrl: profile.profileImage,
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredFadeIn(
              child: CredSection(
                title: 'Today',
                subtitle: 'Store activity so far',
                child: _TodayStatsSection(),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredFadeIn(
              delay: const Duration(milliseconds: 40),
              child: DashboardSalesTrendSection(
                storeOwnerId: storeOwnerId,
                employeeId: profile.id,
                title: 'Your sales trend',
                metric: CredTrendMetric.count,
                seriesLabel: 'Your transactions',
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredFadeIn(
              delay: const Duration(milliseconds: 80),
              child: CredSection(
                title: 'Debts',
                child: _DebtSummarySection(),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Quick Actions',
              child: CredQuickActionGrid(
                actions: [
                  CredQuickAction(
                    label: 'Retail Sales',
                    icon: Icons.point_of_sale,
                    onPressed: () => context.go('/employee/tab3'),
                  ),
                  CredQuickAction(
                    label: 'Products',
                    icon: Icons.inventory_2,
                    onPressed: () => context.go('/employee/tab4'),
                  ),
                  CredQuickAction(
                    label: 'Sales',
                    icon: Icons.receipt_long,
                    onPressed: () => context.go('/employee/tab2'),
                  ),
                  CredQuickAction(
                    label: 'Reports',
                    icon: Icons.assessment,
                    onPressed: () => context.go('/employee/tab5'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Debt Calendar',
              subtitle: 'Upcoming due dates',
              child: _DebtCalendarSection(),
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
    final profile = ref.read(currentProfileProvider).value;
    if (profile != null) {
      final storeOwnerId = resolveStoreOwnerId(profile);
      ref.invalidate(storeProfileProvider(storeOwnerId));
      ref.invalidate(receiptStoreInfoProvider(storeOwnerId));
      ref.invalidate(storeSalesProvider(storeOwnerId));
    }
    await Future.wait([
      ref.read(currentStoreTodayActivityProvider.future),
      ref.read(currentStoreDebtsProvider.future),
      ref.read(currentStoreProductsProvider.future),
      if (profile != null)
        ref.read(storeSalesProvider(resolveStoreOwnerId(profile)).future),
    ]);
  }
}

class _TodayStatsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(currentStoreTodayActivityProvider);
    final lowStock = _lowStockCount(ref);

    return CredAsyncView<Map<String, int>>(
      asyncValue: activity,
      builder: (stats) => CredMetricGrid(
        metrics: [
          CredMetricCard(
            label: 'Cash txns',
            value: '${stats['transactions'] ?? 0}',
            icon: Icons.point_of_sale,
            accentColor: CredTheme.success,
            onTap: () => context.go('/employee/tab2'),
          ),
          CredMetricCard(
            label: 'New debts',
            value: '${stats['newDebts'] ?? 0}',
            icon: Icons.receipt_long,
            accentColor: CredTheme.info,
          ),
          CredMetricCard(
            label: 'Payments',
            value: '${stats['payments'] ?? 0}',
            icon: Icons.payments,
            accentColor: CredTheme.primary,
          ),
          CredMetricCard(
            label: 'Low stock',
            value: '$lowStock',
            icon: Icons.warning_amber,
            accentColor: CredTheme.warning,
            onTap: lowStock > 0 ? () => context.go('/employee/tab4') : null,
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

        return Column(
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
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.schedule,
                  accentColor: CredTheme.warning,
                ),
                CredMetricCard(
                  label: 'Overdue',
                  value: '$overdue',
                  icon: Icons.error_outline,
                  accentColor: CredTheme.danger,
                ),
              ],
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
        onDayTap: (day, dayDebts) => DebtDaySheet.show(
          context,
          date: day,
          debts: dayDebts,
          titleForDebt: (d) => d.customerName?.trim().isNotEmpty == true
              ? d.customerName!
              : 'Customer',
          // Employee Debts nav is POS; Sales is where debt sales are reviewed.
          viewAllLabel: 'Go to Sales',
          onViewAll: () => context.go('/employee/tab2'),
        ),
      ),
    );
  }
}
