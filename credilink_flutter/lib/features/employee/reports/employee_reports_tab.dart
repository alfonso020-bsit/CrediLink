import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/employee_report_pdf_service.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';
import '../../../shared/widgets/reports/report_filter_bar.dart';

class EmployeeReportsTab extends ConsumerStatefulWidget {
  const EmployeeReportsTab({super.key});

  @override
  ConsumerState<EmployeeReportsTab> createState() => _EmployeeReportsTabState();
}

class _EmployeeReportsTabState extends ConsumerState<EmployeeReportsTab> {
  String _typeFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (profile) {
        if (profile == null) return const EmptyState(message: 'No profile');

        final storeOwnerId = resolveStoreOwnerId(profile);
        final salesAsync = ref.watch(storeSalesProvider(storeOwnerId));

        return Column(
          children: [
            ReportFilterBar(
              selectedType: _typeFilter,
              onTypeChanged: (v) => setState(() => _typeFilter = v),
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
              showSearch: false,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportCsv(profile, salesAsync.value ?? []),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ),
                  const SizedBox(width: CredTheme.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportPdf(profile, salesAsync.value ?? []),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CredAsyncView<List<SaleRecord>>(
                asyncValue: salesAsync,
                emptyMessage: 'No transactions',
                onRetry: () => ref.invalidate(storeSalesProvider(storeOwnerId)),
                builder: (sales) {
                  final mine = sales.where((s) => s.employeeId == profile.id).toList();
                  final filtered = mine.where(_matchesFilters).toList();
                  final cashCount = filtered.where((s) => s.type == SaleType.cash).length;
                  final debtCount = filtered.where((s) => s.type == SaleType.debt).length;
                  final revenue = filtered.fold<double>(0, (sum, s) => sum + s.total);

                  if (filtered.isEmpty) {
                    return const EmptyState(message: 'No transactions in this period');
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(storeOwnerId));
                      await ref.read(storeSalesProvider(storeOwnerId).future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: CredTheme.spaceMd),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
                          child: CredMetricGrid(
                            metrics: [
                              CredMetricCard(
                                label: 'Transactions',
                                value: '${filtered.length}',
                                icon: Icons.receipt,
                                accentColor: CredTheme.info,
                              ),
                              CredMetricCard(
                                label: 'Revenue',
                                value: CurrencyFormatter.format(revenue),
                                icon: Icons.trending_up,
                                accentColor: CredTheme.success,
                              ),
                              CredMetricCard(
                                label: 'Cash Sales',
                                value: '$cashCount',
                                icon: Icons.payments,
                                accentColor: CredTheme.success,
                              ),
                              CredMetricCard(
                                label: 'Debt Sales',
                                value: '$debtCount',
                                icon: Icons.account_balance_wallet,
                                accentColor: CredTheme.warning,
                              ),
                            ],
                          ),
                        ),
                        CredSection(
                          title: 'Transactions',
                          child: Column(
                            children: filtered
                                .map(
                                  (sale) => _TransactionTile(
                                    sale: sale,
                                    onTap: () => _showTransactionDetail(context, sale, profile),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesFilters(SaleRecord sale) {
    if (_typeFilter == 'cash' && sale.type != SaleType.cash) return false;
    if (_typeFilter == 'debt' && sale.type != SaleType.debt) return false;
    if (_dateRange == null || sale.createdAt == null) return true;
    final created = sale.createdAt!;
    return !created.isBefore(_dateRange!.start) && created.isBefore(_dateRange!.end);
  }

  Future<void> _exportCsv(UserProfile profile, List<SaleRecord> sales) async {
    final filtered = sales.where((s) => s.employeeId == profile.id).where(_matchesFilters).toList();
    final name = await CsvExportService().exportTransactions(sales: filtered);
    if (mounted) CredSnackBar.show(context, 'Copied $name to clipboard');
  }

  Future<void> _exportPdf(UserProfile profile, List<SaleRecord> sales) async {
    await EmployeeReportPdfService().exportEmployeeReport(
      employee: profile,
      sales: sales,
      dateRange: _dateRange,
    );
  }

  void _showTransactionDetail(BuildContext context, SaleRecord sale, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Transaction Details',
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptView(
              sale: sale,
              storeName: profile.storeName,
              employeeName: profile.fullName,
            ),
            PdfExportButton(
              sale: sale,
              storeName: profile.storeName,
              employeeName: profile.fullName,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.sale,
    required this.onTap,
  });

  final SaleRecord sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cred = CredThemeExtension.of(context);
    final accent = sale.type == SaleType.cash ? cred.success : cred.warning;
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy h:mm a').format(sale.createdAt!)
        : '—';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Icon(
          sale.type == SaleType.cash ? Icons.payments : Icons.receipt_long,
          color: accent,
        ),
      ),
      title: Text(sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in Customer'),
      subtitle: Text('$dateStr • ${sale.type == SaleType.cash ? 'Cash' : 'Debt'}'),
      trailing: Text(
        CurrencyFormatter.format(sale.total),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
