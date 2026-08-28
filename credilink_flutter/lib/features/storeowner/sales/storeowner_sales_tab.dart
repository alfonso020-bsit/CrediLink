import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/sale_filters.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/sales_report_pdf_service.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';
import '../../../shared/widgets/reports/report_filter_bar.dart';

class StoreOwnerSalesTab extends ConsumerStatefulWidget {
  const StoreOwnerSalesTab({super.key});

  @override
  ConsumerState<StoreOwnerSalesTab> createState() => _StoreOwnerSalesTabState();
}

class _StoreOwnerSalesTabState extends ConsumerState<StoreOwnerSalesTab> {
  SaleType _filter = SaleType.cash;
  DateTimeRange? _dateRange;
  String _debtStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        final sales = ref.watch(storeSalesProvider(p.id));
        return Column(
          children: [
            ReportFilterBar(
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(CredTheme.spaceMd, 0, CredTheme.spaceMd, CredTheme.spaceXs),
              child: Row(
                children: [
                  Expanded(
                    child: CredSegmentedFilter<SaleType>(
                      options: const [SaleType.cash, SaleType.debt],
                      selected: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                      labelBuilder: (v) => v == SaleType.cash ? 'Cash' : 'Debt',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Export report',
                    onPressed: () => _exportReport(p, sales.value ?? []),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
            ),
            if (_filter == SaleType.debt)
              Padding(
                padding: const EdgeInsets.fromLTRB(CredTheme.spaceMd, 0, CredTheme.spaceMd, CredTheme.spaceXs),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'unpaid', 'partially_paid', 'paid', 'overdue']
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_statusLabel(s)),
                                selected: _debtStatus == s,
                                onSelected: (_) => setState(() => _debtStatus = s),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            Expanded(
              child: sales.when(
                data: (items) {
                  final filtered = filterSales(
                    items,
                    type: _filter,
                    dateRange: _dateRange,
                    debtStatus: _debtStatus,
                  );
                  if (filtered.isEmpty) {
                    return EmptyState(
                      message: 'No ${_filter == SaleType.cash ? 'cash' : 'debt'} sales in this period',
                    );
                  }
                  final revenue = sumSalesTotal(filtered);
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(p.id));
                      await ref.read(storeSalesProvider(p.id).future);
                    },
                    child: ListView(
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
                            ],
                          ),
                        ),
                        ...filtered.map(
                          (sale) => _SaleTile(
                            sale: sale,
                            profile: p,
                            onTap: () => _showReceipt(context, sale, p),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(message: '$e'),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
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

  Future<void> _exportReport(UserProfile profile, List<SaleRecord> sales) async {
    await SalesReportPdfService().exportSalesReport(
      sales: sales,
      storeName: profile.storeName ?? profile.fullName,
      ownerName: profile.fullName,
      dateRange: _dateRange,
      typeFilter: _filter,
    );
    if (mounted) CredSnackBar.show(context, 'Report generated');
  }

  void _showReceipt(BuildContext context, SaleRecord sale, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Receipt',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptView(
              sale: sale,
              storeName: profile.storeName ?? profile.fullName,
            ),
            if (sale.type == SaleType.debt && (sale.remainingBalance ?? 0) > 0)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _recordPayment(context, sale, profile);
                },
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
              ),
            if (sale.type == SaleType.debt && (sale.remainingBalance ?? 0) > 0)
              const SizedBox(height: CredTheme.spaceXs),
            PdfExportButton(
              sale: sale,
              storeName: profile.storeName ?? profile.fullName,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    SaleRecord sale,
    UserProfile profile,
  ) async {
    final debt = _saleToDebt(sale);
    await PaymentSheet.show(
      context,
      debt: debt,
      onPay: (amount, notes) async {
        await ref.read(paymentRepositoryProvider).recordPayment(
              debtId: sale.id,
              amount: amount,
              currentBalance: debt.remainingBalance,
              notes: notes,
              paidBy: profile.fullName,
            );
        ref.invalidate(storeSalesProvider(profile.id));
        ref.invalidate(storeDebtsProvider(profile.id));
        if (context.mounted) {
          CredSnackBar.show(context, 'Payment recorded');
        }
      },
    );
  }

  DebtRecord _saleToDebt(SaleRecord sale) {
    return DebtRecord(
      id: sale.id,
      customerId: sale.customerId ?? '',
      storeOwnerId: sale.storeOwnerId,
      totalAmount: sale.total,
      remainingBalance: sale.remainingBalance ?? sale.total,
      status: sale.status,
      paymentStatus: sale.paymentStatus ?? 'unpaid',
      customerName: sale.customerName,
      employeeId: sale.employeeId,
      items: sale.items,
      createdAt: sale.createdAt,
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.profile,
    required this.onTap,
  });

  final SaleRecord sale;
  final UserProfile profile;
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
      title: Text(sale.customerName ?? 'Walk-in Customer'),
      subtitle: Text(dateStr),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(sale.total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            sale.type == SaleType.cash ? 'Cash' : (sale.paymentStatus ?? 'Debt'),
            style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
