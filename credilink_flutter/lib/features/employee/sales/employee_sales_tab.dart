import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/debt_record.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
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
  SaleType _filter = SaleType.cash;
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
              onDateRangeChanged: (range) => setState(() => _dateRange = range),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(CredTheme.spaceMd, 0, CredTheme.spaceMd, CredTheme.spaceXs),
              child: CredSegmentedFilter<SaleType>(
                options: const [SaleType.cash, SaleType.debt],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
                labelBuilder: (v) => v == SaleType.cash ? 'Cash' : 'Debt',
              ),
            ),
            Expanded(
              child: CredAsyncView<List<SaleRecord>>(
                asyncValue: salesAsync,
                emptyMessage: 'No ${_filter == SaleType.cash ? 'cash' : 'debt'} sales',
                onRetry: () => ref.invalidate(storeSalesProvider(storeOwnerId)),
                builder: (items) {
                  final filtered = items
                      .where((s) => s.type == _filter)
                      .where(_matchesDateRange)
                      .toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      message: 'No ${_filter == SaleType.cash ? 'cash' : 'debt'} sales in this period',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeSalesProvider(storeOwnerId));
                      await ref.read(storeSalesProvider(storeOwnerId).future);
                    },
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _SaleTile(
                        sale: filtered[i],
                        profile: profile,
                        onTap: () => _showReceipt(context, filtered[i], profile),
                      ),
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

  bool _matchesDateRange(SaleRecord sale) {
    if (_dateRange == null || sale.createdAt == null) return true;
    final created = sale.createdAt!;
    return !created.isBefore(_dateRange!.start) && created.isBefore(_dateRange!.end);
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
              storeName: profile.storeName,
              employeeName: profile.fullName,
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
              storeName: profile.storeName,
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
      title: Text(sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in Customer'),
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
