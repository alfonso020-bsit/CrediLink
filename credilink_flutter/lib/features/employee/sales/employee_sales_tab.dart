import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/sale_filters.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_modal.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../../../shared/widgets/receipts/pdf_export_button.dart';
import '../../../shared/widgets/receipts/receipt_view.dart';
import '../../../shared/widgets/reports/report_filter_bar.dart';

class EmployeeSalesTab extends ConsumerStatefulWidget {
  const EmployeeSalesTab({super.key});

  @override
  ConsumerState<EmployeeSalesTab> createState() => _EmployeeSalesTabState();
}

class _EmployeeSalesTabState extends ConsumerState<EmployeeSalesTab> {
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
        if (profile == null) {
          return const EmptyState(
            title: 'No profile',
            message: 'Unable to load your account.',
          );
        }

        final storeOwnerId = resolveStoreOwnerId(profile);
        final salesAsync = ref.watch(storeSalesProvider(storeOwnerId));

        return Column(
          children: [
            ReportFilterBar(
              selectedType: _typeFilter,
              onTypeChanged: (v) => setState(() => _typeFilter = v),
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
            ),
            Expanded(
              child: CredAsyncView<List<SaleRecord>>(
                asyncValue: salesAsync,
                emptyMessage: 'No sales',
                onRetry: () => ref.invalidate(storeSalesProvider(storeOwnerId)),
                builder: (items) {
                  final filtered = filterSales(
                    items,
                    type: _saleType,
                    dateRange: _dateRange,
                  );

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      title: 'No sales',
                      message: 'No sales in this period',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(storeOwnerId));
                      await ref.read(storeSalesProvider(storeOwnerId).future);
                    },
                    child: ListView(
                      padding: CredTheme.pagePadding,
                      children: [
                        CredSection(
                          title: 'Store sales',
                          subtitle: 'All transactions at your store',
                          child: Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                                _SaleTile(
                                  sale: filtered[i],
                                  onTap: () => _showReceipt(context, filtered[i], profile),
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

  Future<void> _showReceipt(BuildContext context, SaleRecord sale, UserProfile profile) async {
    final storeOwnerId = resolveStoreOwnerId(profile);
    final storeInfo = await ref.read(receiptStoreInfoProvider(storeOwnerId).future);
    if (!context.mounted) return;

    showCredModal(
      context: context,
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
              employeeName: profile.fullName,
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
              employeeName: profile.fullName,
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
    final storeOwnerId = resolveStoreOwnerId(profile);
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
        ref.invalidate(storeSalesProvider(storeOwnerId));
        ref.invalidate(currentStoreDebtsProvider);
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
      subtitle: Text('$dateStr · #$shortId · $itemLabel'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(sale.total),
            style: CredTheme.listAmountStyle(context),
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
