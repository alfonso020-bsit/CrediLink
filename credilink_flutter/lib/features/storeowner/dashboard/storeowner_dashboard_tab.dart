import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/calendar/debt_calendar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_profile_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/reports/report_filter_bar.dart';

class StoreOwnerDashboardTab extends ConsumerStatefulWidget {
  const StoreOwnerDashboardTab({super.key});

  @override
  ConsumerState<StoreOwnerDashboardTab> createState() => _StoreOwnerDashboardTabState();
}

class _StoreOwnerDashboardTabState extends ConsumerState<StoreOwnerDashboardTab> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        return CredTabPageLayout(
          onRefresh: () => _refresh(ref),
          children: [
            ReportFilterBar(
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
            ),
            CredProfileCard(
              fullName: p.fullName,
              role: UserRole.storeOwner,
              storeName: p.storeName,
              subtitle: '${p.barangay}, ${p.municipality}, ${p.province}',
              imageUrl: p.profileImage,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: "Today's Activity",
              child: _TodayStatsSection(storeOwnerId: p.id, onLowStockTap: () => context.go('/storeowner/tab4')),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Recent Transactions',
              child: _RecentTransactionsSection(storeOwnerId: p.id, dateRange: _dateRange),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Top Employees',
              child: _TopEmployeesSection(storeOwnerId: p.id, dateRange: _dateRange),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Debt Summary',
              child: _DebtSummarySection(storeOwnerId: p.id),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Debt Calendar',
              child: _DebtCalendarSection(profile: p),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
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
  const _TodayStatsSection({required this.storeOwnerId, this.onLowStockTap});

  final String storeOwnerId;
  final VoidCallback? onLowStockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(storeTodayActivityProvider(storeOwnerId));
    return activity.when(
      data: (stats) => CredMetricGrid(
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
            subtitle: onLowStockTap != null ? 'Tap inventory tab' : null,
          ),
        ],
      ),
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => EmptyState(message: '$e'),
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
    return debts.when(
      data: (items) {
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
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DebtCalendarSection extends ConsumerWidget {
  const _DebtCalendarSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(storeDebtsProvider(profile.id));
    return debts.when(
      data: (items) => DebtCalendar(
        debts: items,
        onDebtTap: (debt) => DebtReceiptSheet.show(context, debt),
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }
}

class _RecentTransactionsSection extends ConsumerWidget {
  const _RecentTransactionsSection({required this.storeOwnerId, this.dateRange});

  final String storeOwnerId;
  final DateTimeRange? dateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(storeSalesProvider(storeOwnerId));
    return sales.when(
      data: (items) {
        var filtered = items;
        if (dateRange != null) {
          filtered = items.where((s) {
            if (s.createdAt == null) return false;
            final c = s.createdAt!;
            return !c.isBefore(dateRange!.start) && c.isBefore(dateRange!.end);
          }).toList();
        }
        final recent = filtered.take(5).toList();
        if (recent.isEmpty) return Text('No transactions', style: CredTheme.bodyMutedStyle(context));
        return Column(
          children: recent.map((s) {
            final date = s.createdAt != null ? DateFormat('MMM d, h:mm a').format(s.createdAt!) : '—';
            return ListTile(
              dense: true,
              leading: Icon(s.type == SaleType.cash ? Icons.payments : Icons.receipt_long),
              title: Text(s.customerName ?? 'Walk-in'),
              subtitle: Text(date),
              trailing: Text(CurrencyFormatter.format(s.total)),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }
}

class _TopEmployeesSection extends ConsumerWidget {
  const _TopEmployeesSection({required this.storeOwnerId, this.dateRange});

  final String storeOwnerId;
  final DateTimeRange? dateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(storeSalesProvider(storeOwnerId));
    final employees = ref.watch(storeEmployeesProvider(storeOwnerId));
    return sales.when(
      data: (items) {
        var filtered = items;
        if (dateRange != null) {
          filtered = items.where((s) {
            if (s.createdAt == null) return false;
            final c = s.createdAt!;
            return !c.isBefore(dateRange!.start) && c.isBefore(dateRange!.end);
          }).toList();
        }
        final totals = <String, double>{};
        for (final s in filtered) {
          final id = s.employeeId ?? 'unknown';
          totals[id] = (totals[id] ?? 0) + s.total;
        }
        final ranked = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.take(5).toList();
        if (top.isEmpty) return Text('No employee sales', style: CredTheme.bodyMutedStyle(context));
        final nameMap = {for (final e in employees.value ?? []) e.id: e.fullName};
        return Column(
          children: top.map((e) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.badge),
              title: Text(nameMap[e.key] ?? 'Employee'),
              trailing: Text(CurrencyFormatter.format(e.value)),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
