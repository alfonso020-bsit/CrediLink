import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/debt_report_pdf_service.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';

enum _DebtView { overview, all, customers, employees }

class StoreOwnerDebtsTab extends ConsumerStatefulWidget {
  const StoreOwnerDebtsTab({super.key});

  @override
  ConsumerState<StoreOwnerDebtsTab> createState() => _StoreOwnerDebtsTabState();
}

class _StoreOwnerDebtsTabState extends ConsumerState<StoreOwnerDebtsTab> {
  _DebtView _view = _DebtView.overview;
  String _statusFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        final debts = ref.watch(storeDebtsProvider(p.id));
        final employees = ref.watch(storeEmployeesProvider(p.id));
        final employeeNames = {
          for (final e in employees.value ?? <UserProfile>[]) e.id: e.fullName,
        };

        return CredAsyncView<List<DebtRecord>>(
          asyncValue: debts,
          builder: (items) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CredTheme.spaceMd,
                  CredTheme.spaceMd,
                  CredTheme.spaceMd,
                  CredTheme.spaceXs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CredSegmentedFilter<_DebtView>(
                        options: const [
                          _DebtView.overview,
                          _DebtView.all,
                          _DebtView.customers,
                          _DebtView.employees,
                        ],
                        selected: _view,
                        onChanged: (v) => setState(() => _view = v),
                        labelBuilder: (v) => switch (v) {
                          _DebtView.overview => 'Overview',
                          _DebtView.all => 'All',
                          _DebtView.customers => 'Customers',
                          _DebtView.employees => 'Employees',
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Export PDF',
                      onPressed: () async {
                        await DebtReportPdfService().exportDebtReport(
                          debts: items,
                          storeName: p.storeName ?? p.fullName,
                          ownerName: p.fullName,
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
              ),
              if (_view != _DebtView.overview) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
                  child: CredSearchField(
                    controller: _searchController,
                    hint: 'Search customer or phone',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: CredTheme.spaceXs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
                  child: Row(
                    children: ['all', 'unpaid', 'partially_paid', 'paid', 'overdue']
                        .map(
                          (status) => Padding(
                            padding: const EdgeInsets.only(right: CredTheme.spaceXs),
                            child: FilterChip(
                              label: Text(_statusLabel(status)),
                              selected: _statusFilter == status,
                              onSelected: (_) => setState(() => _statusFilter = status),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: CredTheme.spaceXs),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storeDebtsProvider(p.id));
                    ref.invalidate(storeEmployeesProvider(p.id));
                    await Future.wait([
                      ref.read(storeDebtsProvider(p.id).future),
                      ref.read(storeEmployeesProvider(p.id).future),
                    ]);
                  },
                  child: _buildBody(context, items, p, employeeNames),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DebtRecord> debts,
    UserProfile profile,
    Map<String, String> employeeNames,
  ) {
    return switch (_view) {
      _DebtView.overview => _OverviewView(
          debts: debts,
          onOverdueTap: () => setState(() {
                _view = _DebtView.all;
                _statusFilter = 'overdue';
              }),
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
      _DebtView.all => _DebtListView(
          debts: _filteredDebts(debts),
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
      _DebtView.customers => _CustomersView(
          debts: _filteredDebts(debts),
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
      _DebtView.employees => _EmployeesView(
          debts: _filteredDebts(debts),
          employeeNames: employeeNames,
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
    };
  }

  List<DebtRecord> _filteredDebts(List<DebtRecord> debts) {
    var filtered = debts;
    final term = _searchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      filtered = filtered
          .where(
            (d) =>
                (d.customerName ?? '').toLowerCase().contains(term) ||
                (d.customerPhone ?? '').contains(term),
          )
          .toList();
    }
    if (_statusFilter != 'all') {
      filtered = filtered.where((d) {
        if (_statusFilter == 'overdue') return d.isOverdue && !d.isPaid;
        return d.paymentStatus == _statusFilter;
      }).toList();
    }
    return filtered;
  }

  Future<void> _recordPayment(
    BuildContext context,
    DebtRecord debt,
    UserProfile profile,
  ) async {
    await PaymentSheet.show(
      context,
      debt: debt,
      onPay: (amount, notes) async {
        await ref.read(paymentRepositoryProvider).recordPayment(
              debtId: debt.id!,
              amount: amount,
              currentBalance: debt.remainingBalance,
              notes: notes,
              paidBy: profile.fullName,
            );
        ref.invalidate(storeDebtsProvider(profile.id));
        if (context.mounted) {
          CredSnackBar.show(context, 'Payment recorded');
        }
      },
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'all' => 'All',
      'unpaid' => 'Unpaid',
      'partially_paid' => 'Partial',
      'paid' => 'Paid',
      'overdue' => 'Overdue',
      _ => status,
    };
  }
}

class _OverviewView extends StatelessWidget {
  const _OverviewView({
    required this.debts,
    required this.onOverdueTap,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final VoidCallback onOverdueTap;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    final outstanding = debts.fold<double>(0, (s, d) => s + d.remainingBalance);
    final overdue = debts.where((d) => d.isOverdue && !d.isPaid).length;
    final pending = debts.where((d) => !d.isPaid).length;
    final unpaid = debts.where((d) => d.paymentStatus == 'unpaid').length;
    final partial = debts.where((d) => d.paymentStatus == 'partially_paid').length;
    final paid = debts.where((d) => d.isPaid).length;
    final overdueDebts = debts.where((d) => d.isOverdue && !d.isPaid).toList();

    return ListView(
      padding: CredTheme.pagePadding,
      children: [
        CredSection(
          title: 'Summary',
          subtitle: overdue > 0 ? '$overdue overdue need attention' : 'All clear on overdue',
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
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.schedule,
                    accentColor: CredTheme.warning,
                  ),
                  CredMetricCard(
                    label: 'Overdue',
                    value: '$overdue',
                    icon: Icons.warning_amber,
                    accentColor: CredTheme.danger,
                    subtitle: overdue > 0 ? 'Tap to view' : null,
                    onTap: overdue > 0 ? onOverdueTap : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: CredTheme.spaceLg),
        CredSection(
          title: 'Status breakdown',
          child: Material(
            color: CredTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CredTheme.radiusCard),
              side: const BorderSide(color: CredTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CredTheme.spaceMd),
              child: Column(
                children: [
                  _BreakdownRow(label: 'Unpaid', count: unpaid, color: CredTheme.info),
                  _BreakdownRow(label: 'Partially paid', count: partial, color: CredTheme.warning),
                  _BreakdownRow(label: 'Paid', count: paid, color: CredTheme.success),
                  _BreakdownRow(label: 'Overdue', count: overdue, color: CredTheme.danger),
                ],
              ),
            ),
          ),
        ),
        if (overdueDebts.isNotEmpty) ...[
          const SizedBox(height: CredTheme.spaceLg),
          CredSection(
            title: 'Overdue alerts',
            trailing: TextButton(
              onPressed: onOverdueTap,
              child: Text('View all ($overdue)'),
            ),
            child: Column(
              children: [
                for (var i = 0; i < overdueDebts.take(5).length; i++) ...[
                  if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                  _DebtTile(
                    debt: overdueDebts[i],
                    onPay: () => onPay(overdueDebts[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: CredTheme.spaceXs),
          Expanded(child: Text(label)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DebtListView extends StatelessWidget {
  const _DebtListView({
    required this.debts,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(message: 'No debts match filters'),
        ],
      );
    }
    return ListView.separated(
      padding: CredTheme.pagePadding,
      itemCount: debts.length,
      separatorBuilder: (_, _) => const SizedBox(height: CredTheme.spaceXs),
      itemBuilder: (_, i) => _DebtTile(debt: debts[i], onPay: () => onPay(debts[i])),
    );
  }
}

class _CustomersView extends StatelessWidget {
  const _CustomersView({
    required this.debts,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<DebtRecord>>{};
    for (final debt in debts.where((d) => !d.isPaid)) {
      final key = debt.customerPhone ?? debt.customerName ?? debt.customerId;
      grouped.putIfAbsent(key, () => []).add(debt);
    }

    final customers = grouped.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final bTotal = b.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        return bTotal.compareTo(aTotal);
      });

    if (customers.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(message: 'No customers with outstanding debt'),
        ],
      );
    }

    return ListView.separated(
      padding: CredTheme.pagePadding,
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: CredTheme.spaceXs),
      itemBuilder: (_, i) {
        final entry = customers[i];
        final total = entry.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final name = entry.value.first.customerName ?? 'Customer';
        final hasOverdue = entry.value.any((d) => d.isOverdue && !d.isPaid);

        return Material(
          color: CredTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CredTheme.radiusCard),
            side: BorderSide(
              color: hasOverdue
                  ? CredTheme.danger.withValues(alpha: 0.35)
                  : CredTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
            childrenPadding: const EdgeInsets.fromLTRB(
              CredTheme.spaceSm,
              0,
              CredTheme.spaceSm,
              CredTheme.spaceSm,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${entry.value.length} debt(s) · ${entry.key}'),
            trailing: Text(
              CurrencyFormatter.format(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              for (var j = 0; j < entry.value.length; j++) ...[
                if (j > 0) const SizedBox(height: CredTheme.spaceXs),
                _DebtTile(debt: entry.value[j], onPay: () => onPay(entry.value[j])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmployeesView extends StatelessWidget {
  const _EmployeesView({
    required this.debts,
    required this.employeeNames,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final Map<String, String> employeeNames;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<DebtRecord>>{};
    for (final debt in debts.where((d) => !d.isPaid)) {
      final key = debt.employeeId ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(debt);
    }

    if (grouped.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(message: 'No employee-linked debts'),
        ],
      );
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final bTotal = b.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        return bTotal.compareTo(aTotal);
      });

    return ListView.separated(
      padding: CredTheme.pagePadding,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: CredTheme.spaceXs),
      itemBuilder: (_, i) {
        final entry = entries[i];
        final total = entry.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final name = employeeNames[entry.key] ?? 'Unassigned';
        final hasOverdue = entry.value.any((d) => d.isOverdue && !d.isPaid);

        return Material(
          color: CredTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CredTheme.radiusCard),
            side: BorderSide(
              color: hasOverdue
                  ? CredTheme.danger.withValues(alpha: 0.35)
                  : CredTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
            childrenPadding: const EdgeInsets.fromLTRB(
              CredTheme.spaceSm,
              0,
              CredTheme.spaceSm,
              CredTheme.spaceSm,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${entry.value.length} debt(s)'),
            trailing: Text(
              CurrencyFormatter.format(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              for (var j = 0; j < entry.value.length; j++) ...[
                if (j > 0) const SizedBox(height: CredTheme.spaceXs),
                _DebtTile(debt: entry.value[j], onPay: () => onPay(entry.value[j])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt, required this.onPay});

  final DebtRecord debt;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final isOverdue = debt.isOverdue && !debt.isPaid;
    final due = debt.dueDate != null ? DateFormat.MMMd().format(debt.dueDate!) : null;

    return CredSurfaceTile(
      onTap: () => DebtReceiptSheet.show(context, debt),
      emphasized: isOverdue,
      leading: Icon(
        debt.isPaid ? Icons.check_circle : Icons.receipt_long,
        color: debt.isPaid
            ? CredTheme.success
            : isOverdue
                ? CredTheme.danger
                : CredTheme.warning,
      ),
      title: Text(debt.customerName ?? debt.customerId),
      subtitle: Text(due != null ? 'Due $due' : 'No due date'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(debt.remainingBalance),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          CredStatusChip.debt(
            paymentStatus: debt.paymentStatus,
            isOverdue: isOverdue,
            compact: true,
          ),
          if (!debt.isPaid) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onPay,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Pay'),
            ),
          ],
        ],
      ),
    );
  }
}
