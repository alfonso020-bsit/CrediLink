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
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/settings/store_settings_sheet.dart';

class StoreOwnerDashboardTab extends ConsumerWidget {
  const StoreOwnerDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (profile) {
        if (profile == null) return const EmptyState(message: 'No profile');

        final store = ref.watch(storeProfileProvider(profile.id)).value;
        final location = [
          profile.barangay,
          profile.municipality,
          profile.province,
        ].where((p) => p.trim().isNotEmpty).join(', ');

        return CredTabPageLayout(
          onRefresh: () => _refresh(ref, profile.id),
          children: [
            CredProfileCard(
              fullName: profile.fullName,
              role: UserRole.storeOwner,
              storeName: profile.storeName,
              subtitle: location.isEmpty ? null : location,
              imageUrl: store?.storeImage ?? profile.profileImage,
              onTap: () => StoreSettingsSheet.show(context, profile),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Today',
              subtitle: 'Store activity so far',
              child: _TodayStatsSection(
                storeOwnerId: profile.id,
                onLowStockTap: () => context.go('/storeowner/tab4'),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Debts',
              child: _DebtSummarySection(storeOwnerId: profile.id),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Quick Actions',
              child: _QuickActionsSection(),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Debt Calendar',
              subtitle: 'Upcoming due dates',
              child: _DebtCalendarSection(storeOwnerId: profile.id),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(WidgetRef ref, String storeOwnerId) async {
    ref.invalidate(storeTodayActivityProvider(storeOwnerId));
    ref.invalidate(storeDebtsProvider(storeOwnerId));
    ref.invalidate(storeProfileProvider(storeOwnerId));
    ref.invalidate(currentStoreProductsProvider);
    await Future.wait([
      ref.read(storeTodayActivityProvider(storeOwnerId).future),
      ref.read(storeDebtsProvider(storeOwnerId).future),
      ref.read(currentStoreProductsProvider.future),
    ]);
  }
}

class _TodayStatsSection extends ConsumerWidget {
  const _TodayStatsSection({
    required this.storeOwnerId,
    this.onLowStockTap,
  });

  final String storeOwnerId;
  final VoidCallback? onLowStockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(storeTodayActivityProvider(storeOwnerId));

    return CredAsyncView<Map<String, int>>(
      asyncValue: activity,
      builder: (stats) => CredMetricGrid(
        metrics: [
          CredMetricCard(
            label: 'Cash sales',
            value: '${stats['transactions'] ?? 0}',
            icon: Icons.point_of_sale,
            accentColor: CredTheme.success,
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
            value: '${_lowStockCount(ref)}',
            icon: Icons.warning_amber,
            accentColor: CredTheme.warning,
            onTap: onLowStockTap,
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
  const _DebtSummarySection({required this.storeOwnerId});

  final String storeOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(storeDebtsProvider(storeOwnerId));

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
  const _DebtCalendarSection({required this.storeOwnerId});

  final String storeOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(storeDebtsProvider(storeOwnerId));

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

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CredQuickActionGrid(
      actions: [
        CredQuickAction(
          label: 'POS',
          icon: Icons.point_of_sale,
          onPressed: () => context.go('/storeowner/tab2'),
        ),
        CredQuickAction(
          label: 'Debts',
          icon: Icons.receipt_long,
          onPressed: () => context.go('/storeowner/tab3'),
        ),
        CredQuickAction(
          label: 'Inventory',
          icon: Icons.inventory_2,
          onPressed: () => context.go('/storeowner/tab4'),
        ),
        CredQuickAction(
          label: 'Employees',
          icon: Icons.groups,
          onPressed: () => context.go('/storeowner/tab5'),
        ),
      ],
    );
  }
}
