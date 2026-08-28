import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../../../services/debt_report_pdf_service.dart';
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
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        final debts = ref.watch(storeDebtsProvider(p.id));
        return debts.when(
          data: (items) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CredTheme.spaceMd, CredTheme.spaceMd, CredTheme.spaceMd, CredTheme.spaceXs),
                child: Row(
                  children: [
                    Expanded(
                      child: CredSegmentedFilter<_DebtView>(
                        options: const [_DebtView.overview, _DebtView.all, _DebtView.customers, _DebtView.employees],
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search customer or phone',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['all', 'unpaid', 'partially_paid', 'paid', 'overdue']
                        .map((status) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_statusLabel(status)),
                                selected: _statusFilter == status,
                                onSelected: (_) => setState(() => _statusFilter = status),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storeDebtsProvider(p.id));
                    await ref.read(storeDebtsProvider(p.id).future);
                  },
                  child: _buildBody(context, items, p),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(message: '$e'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }

  Widget _buildBody(BuildContext context, List<DebtRecord> debts, UserProfile profile) {
    return switch (_view) {
      _DebtView.overview => _OverviewView(debts: debts),
      _DebtView.all => _DebtListView(
          debts: _filteredDebts(debts),
          profile: profile,
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
      _DebtView.customers => _CustomersView(
          debts: _filteredDebts(debts),
          profile: profile,
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
      _DebtView.employees => _EmployeesView(
          debts: _filteredDebts(debts),
          profile: profile,
          onPay: (debt) => _recordPayment(context, debt, profile),
        ),
    };
  }

  List<DebtRecord> _filteredDebts(List<DebtRecord> debts) {
    var filtered = debts;
    final term = _searchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      filtered = filtered
          .where((d) =>
              (d.customerName ?? '').toLowerCase().contains(term) ||
              (d.customerPhone ?? '').contains(term))
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
  const _OverviewView({required this.debts});

  final List<DebtRecord> debts;

  @override
  Widget build(BuildContext context) {
    final outstanding = debts.fold<double>(0, (s, d) => s + d.remainingBalance);
    final overdue = debts.where((d) => d.isOverdue && !d.isPaid).length;
    final unpaid = debts.where((d) => d.paymentStatus == 'unpaid').length;
    final partial = debts.where((d) => d.paymentStatus == 'partially_paid').length;
    final paid = debts.where((d) => d.isPaid).length;
    final overdueDebts = debts.where((d) => d.isOverdue && !d.isPaid).toList();

    return ListView(
      padding: CredTheme.pagePadding,
      children: [
        CredMetricGrid(
          metrics: [
            CredMetricCard(
              label: 'Outstanding',
              value: CurrencyFormatter.format(outstanding),
              icon: Icons.account_balance_wallet,
              accentColor: CredTheme.warning,
            ),
            CredMetricCard(
              label: 'Overdue',
              value: '$overdue',
              icon: Icons.warning,
              accentColor: CredTheme.danger,
            ),
            CredMetricCard(
              label: 'Unpaid',
              value: '$unpaid',
              icon: Icons.pending,
              accentColor: CredTheme.danger,
            ),
            CredMetricCard(
              label: 'Paid',
              value: '$paid',
              icon: Icons.check_circle,
              accentColor: CredTheme.success,
            ),
          ],
        ),
        const SizedBox(height: CredTheme.spaceMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(CredTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Breakdown', style: CredTheme.sectionTitle(context)),
                const SizedBox(height: CredTheme.spaceSm),
                _BreakdownRow(label: 'Unpaid', count: unpaid, color: CredTheme.danger),
                _BreakdownRow(label: 'Partially Paid', count: partial, color: CredTheme.warning),
                _BreakdownRow(label: 'Paid', count: paid, color: CredTheme.success),
                _BreakdownRow(label: 'Overdue', count: overdue, color: CredTheme.danger),
              ],
            ),
          ),
        ),
        if (overdueDebts.isNotEmpty) ...[
          const SizedBox(height: CredTheme.spaceMd),
          CredSection(
            title: 'Overdue Alerts',
            child: Column(
              children: overdueDebts.take(5).map((d) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning, color: CredTheme.danger),
                      title: Text(d.customerName ?? d.customerId),
                      subtitle: Text(
                        'Due ${d.dueDate != null ? DateFormat.yMMMd().format(d.dueDate!) : '—'}',
                      ),
                      trailing: Text(CurrencyFormatter.format(d.remainingBalance)),
                    ),
                  )).toList(),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
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
    required this.profile,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final UserProfile profile;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const EmptyState(message: 'No debts match filters');
    return ListView.builder(
      itemCount: debts.length,
      itemBuilder: (_, i) => _DebtTile(debt: debts[i], onPay: () => onPay(debts[i])),
    );
  }
}

class _CustomersView extends StatelessWidget {
  const _CustomersView({
    required this.debts,
    required this.profile,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final UserProfile profile;
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

    if (customers.isEmpty) return const EmptyState(message: 'No customers with outstanding debt');

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (_, i) {
        final entry = customers[i];
        final total = entry.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final name = entry.value.first.customerName ?? 'Customer';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text(name),
            subtitle: Text('${entry.value.length} debt(s) • ${entry.key}'),
            trailing: Text(
              CurrencyFormatter.format(total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: entry.value
                .map((d) => _DebtTile(debt: d, onPay: () => onPay(d)))
                .toList(),
          ),
        );
      },
    );
  }
}

class _EmployeesView extends StatelessWidget {
  const _EmployeesView({
    required this.debts,
    required this.profile,
    required this.onPay,
  });

  final List<DebtRecord> debts;
  final UserProfile profile;
  final void Function(DebtRecord debt) onPay;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<DebtRecord>>{};
    for (final debt in debts.where((d) => !d.isPaid)) {
      final key = debt.employeeId ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(debt);
    }

    if (grouped.isEmpty) return const EmptyState(message: 'No employee-linked debts');

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        final bTotal = b.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        return bTotal.compareTo(aTotal);
      });

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        final total = entry.value.fold<double>(0, (s, d) => s + d.remainingBalance);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text('Employee ${entry.key.substring(0, entry.key.length.clamp(0, 8))}'),
            subtitle: Text('${entry.value.length} debt(s)'),
            trailing: Text(
              CurrencyFormatter.format(total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: entry.value
                .map((d) => _DebtTile(debt: d, onPay: () => onPay(d)))
                .toList(),
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
    final cred = CredThemeExtension.of(context);
    final isOverdue = debt.isOverdue && !debt.isPaid;
    final iconColor = debt.isPaid
        ? cred.success
        : isOverdue
            ? cred.danger
            : cred.warning;
    return ListTile(
      leading: Icon(
        debt.isPaid ? Icons.check_circle : Icons.receipt_long,
        color: iconColor,
      ),
      title: Text(debt.customerName ?? debt.customerId),
      subtitle: Text(
        '${debt.paymentStatus}${debt.dueDate != null ? ' • Due ${DateFormat.MMMd().format(debt.dueDate!)}' : ''}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(debt.remainingBalance),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (!debt.isPaid)
            TextButton(onPressed: onPay, child: const Text('Pay')),
        ],
      ),
      onTap: () => DebtReceiptSheet.show(context, debt),
    );
  }
}
