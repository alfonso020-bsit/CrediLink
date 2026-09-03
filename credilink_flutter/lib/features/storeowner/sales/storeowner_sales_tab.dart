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
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
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
  String _typeFilter = 'all';
  DateTimeRange? _dateRange;
  String _debtStatus = 'all';

  SaleType? get _saleType {
    return switch (_typeFilter) {
      'cash' => SaleType.cash,
      'debt' => SaleType.debt,
      _ => null,
    };
  }

  String get _summarySubtitle {
    return switch (_typeFilter) {
      'cash' => 'Cash sales',
      'debt' => 'Debt sales',
      _ => 'All sales',
    };
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        final sales = ref.watch(storeSalesProvider(p.id));
        final employees = ref.watch(storeEmployeesProvider(p.id));
        final employeeNames = {
          for (final e in employees.value ?? <UserProfile>[]) e.id: e.fullName,
        };

        return Column(
          children: [
            ReportFilterBar(
              selectedType: _typeFilter,
              onTypeChanged: (v) => setState(() {
                _typeFilter = v;
                if (v != 'debt') _debtStatus = 'all';
              }),
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
              trailing: IconButton(
                tooltip: 'Export report',
                onPressed: () => _exportReport(p, sales.value ?? []),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ),
            if (_typeFilter == 'debt')
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CredTheme.spaceMd,
                  0,
                  CredTheme.spaceMd,
                  CredTheme.spaceXs,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'unpaid', 'partially_paid', 'paid', 'overdue']
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: CredTheme.spaceXs),
                            child: FilterChip(
                              label: Text(_statusLabel(s)),
                              selected: _debtStatus == s,
                              onSelected: (_) => setState(() => _debtStatus = s),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            Expanded(
              child: CredAsyncView<List<SaleRecord>>(
                asyncValue: sales,
                builder: (items) {
                  final filtered = filterSales(
                    items,
                    type: _saleType,
                    dateRange: _dateRange,
                    debtStatus: _debtStatus,
                  );
                  final revenue = sumSalesTotal(filtered);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(p.id));
                      await ref.read(storeSalesProvider(p.id).future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        CredTheme.spaceMd,
                        CredTheme.spaceXs,
                        CredTheme.spaceMd,
                        CredTheme.spaceLg,
                      ),
                      children: [
                        CredSection(
                          title: 'Summary',
                          subtitle: _summarySubtitle,
                          child: CredMetricGrid(
                            metrics: [
                              CredMetricCard(
                                label: 'Revenue',
                                value: CurrencyFormatter.format(revenue),
                                icon: Icons.trending_up,
                                accentColor: CredTheme.success,
                              ),
                              CredMetricCard(
                                label: 'Transactions',
                                value: '${filtered.length}',
                                icon: Icons.receipt,
                                accentColor: CredTheme.info,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CredTheme.spaceLg),
                        CredSection(
                          title: 'Transactions',
                          child: filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
                                  child: EmptyState(message: 'No sales in this period'),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < filtered.length; i++) ...[
                                      if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                                      _SaleTile(
                                        sale: filtered[i],
                                        onTap: () => _showReceipt(
                                          context,
                                          filtered[i],
                                          p,
                                          employeeNames[filtered[i].employeeId ?? ''],
                                        ),
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
      typeFilter: _saleType,
    );
    if (mounted) CredSnackBar.show(context, 'Report generated');
  }

  Future<void> _showReceipt(
    BuildContext context,
    SaleRecord sale,
    UserProfile profile,
    String? employeeName,
  ) async {
    final storeInfo = await ref.read(receiptStoreInfoProvider(profile.id).future);
    if (!context.mounted) return;

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
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
              employeeName: employeeName,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            if (sale.type == SaleType.debt && (sale.remainingBalance ?? 0) > 0) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _recordPayment(context, sale, profile);
                },
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
              ),
              const SizedBox(height: CredTheme.spaceXs),
            ],
            PdfExportButton(
              sale: sale,
              storeName: storeInfo.name,
              storeLogoUrl: storeInfo.logoUrl,
              receiptHeader: storeInfo.receiptHeader,
              receiptFooter: storeInfo.receiptFooter,
              employeeName: employeeName,
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
    required this.onTap,
  });

  final SaleRecord sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCash = sale.type == SaleType.cash;
    final isOverdue = !isCash && sale.status == 'overdue';
    final remaining = sale.remainingBalance ?? 0;
    final dateStr = sale.createdAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(sale.createdAt!)
        : '—';
    final shortId = sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id;
    final itemCount = sale.items.length;
    final itemLabel = itemCount == 1 ? '1 item' : '$itemCount items';

    return CredSurfaceTile(
      onTap: onTap,
      emphasized: isOverdue,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$dateStr · #$shortId · $itemLabel'),
          if (!isCash && remaining > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Balance ${CurrencyFormatter.format(remaining)}',
              style: const TextStyle(color: CredTheme.warning, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(sale.total),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: CredTheme.titleText,
            ),
          ),
          const SizedBox(height: 4),
          if (isCash)
            CredStatusChip.saleType(isCash: true, compact: true)
          else
            CredStatusChip.debt(
              paymentStatus: sale.paymentStatus ?? 'unpaid',
              isOverdue: isOverdue,
              compact: true,
            ),
        ],
      ),
    );
  }
}
