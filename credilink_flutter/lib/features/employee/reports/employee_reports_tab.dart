import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/sale_filters.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/employee_report_pdf_service.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
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

  SaleType? get _saleType {
    return switch (_typeFilter) {
      'cash' => SaleType.cash,
      'debt' => SaleType.debt,
      _ => null,
    };
  }

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
                  final filtered = _filteredMine(sales, profile.id);
                  final cashCount = filtered.where((s) => s.type == SaleType.cash).length;
                  final debtCount = filtered.where((s) => s.type == SaleType.debt).length;
                  final revenue = filtered.fold<double>(0, (sum, s) => sum + s.total);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(storeOwnerId));
                      await ref.read(storeSalesProvider(storeOwnerId).future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        CredTheme.spaceMd,
                        CredTheme.spaceSm,
                        CredTheme.spaceMd,
                        CredTheme.spaceMd,
                      ),
                      children: [
                        CredSection(
                          title: 'Your transactions',
                          subtitle: 'Sales you processed',
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
                                label: 'Cash',
                                value: '$cashCount',
                                icon: Icons.payments,
                                accentColor: CredTheme.success,
                              ),
                              CredMetricCard(
                                label: 'Debt',
                                value: '$debtCount',
                                icon: Icons.account_balance_wallet,
                                accentColor: CredTheme.warning,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CredTheme.spaceLg),
                        CredSection(
                          title: 'History',
                          child: filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
                                  child: EmptyState(message: 'No transactions in this period'),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < filtered.length; i++) ...[
                                      if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                                      _TransactionTile(
                                        sale: filtered[i],
                                        onTap: () =>
                                            _showTransactionDetail(context, filtered[i], profile),
                                      ),
                                    ],
                                  ],
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

  List<SaleRecord> _filteredMine(List<SaleRecord> sales, String employeeId) {
    final mine = sales.where((s) => s.employeeId == employeeId).toList();
    return filterSales(
      mine,
      type: _saleType,
      dateRange: _dateRange,
    );
  }

  Future<void> _exportCsv(UserProfile profile, List<SaleRecord> sales) async {
    final filtered = _filteredMine(sales, profile.id);
    final name = await CsvExportService().exportTransactions(sales: filtered);
    if (mounted) CredSnackBar.show(context, 'Copied $name to clipboard');
  }

  Future<void> _exportPdf(UserProfile profile, List<SaleRecord> sales) async {
    final filtered = _filteredMine(sales, profile.id);
    await EmployeeReportPdfService().exportEmployeeReport(
      employee: profile,
      sales: filtered,
      dateRange: _dateRange,
    );
  }

  Future<void> _showTransactionDetail(BuildContext context, SaleRecord sale, UserProfile profile) async {
    final storeOwnerId = resolveStoreOwnerId(profile);
    final storeInfo = await ref.read(receiptStoreInfoProvider(storeOwnerId).future);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Transaction Details',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptView(
              sale: sale,
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
              employeeName: profile.fullName,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            PdfExportButton(
              sale: sale,
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
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
    final isCash = sale.type == SaleType.cash;
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(sale.createdAt!)
        : '—';
    final shortId = sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id;
    final itemCount = sale.items.length;
    final itemLabel = itemCount == 1 ? '1 item' : '$itemCount items';

    return CredSurfaceTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: (isCash ? CredTheme.success : CredTheme.info).withValues(alpha: 0.15),
        child: Icon(
          isCash ? Icons.payments : Icons.receipt_long,
          color: isCash ? CredTheme.success : CredTheme.info,
          size: 20,
        ),
      ),
      title: Text(
        (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
            ? sale.customerName!
            : 'Walk-in',
      ),
      subtitle: Text('$dateStr · #$shortId · $itemLabel'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(sale.total),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          CredStatusChip.saleType(isCash: isCash, compact: true),
        ],
      ),
    );
  }
}
