import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/payment_history_entry.dart';
import '../../../repositories/repositories.dart';
import '../layout/cred_modal.dart';
import '../layout/cred_sheet_scaffold.dart';
import '../settings/contact_store_button.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.debt,
    required this.onPay,
  });

  final DebtRecord debt;
  final Future<void> Function(double amount, String? notes) onPay;

  static Future<void> show(
    BuildContext context, {
    required DebtRecord debt,
    required Future<void> Function(double amount, String? notes) onPay,
  }) {
    return showCredModal(
      context: context,
      builder: (_) => PaymentSheet(debt: debt, onPay: onPay),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CredSheetScaffold(
      title: 'Record Payment',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Balance: ${CurrencyFormatter.format(widget.debt.remainingBalance)}',
          ),
          const SizedBox(height: CredTheme.spaceMd),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: CredTheme.spaceSm),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: CredTheme.spaceMd),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
                    final raw = _amountController.text.trim();
                    final amount = double.tryParse(raw);
                    if (amount == null || amount <= 0) {
                      CredSnackBar.show(context, 'Enter a valid amount', isError: true);
                      return;
                    }
                    if (amount > widget.debt.remainingBalance) {
                      CredSnackBar.show(context, 'Amount exceeds balance', isError: true);
                      return;
                    }

                    setState(() => _loading = true);
                    try {
                      await widget.onPay(
                        amount,
                        _notesController.text.isEmpty ? null : _notesController.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        CredSnackBar.show(context, '$e', isError: true);
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Payment'),
          ),
        ],
      ),
    );
  }
}

class DebtReceiptSheet extends ConsumerWidget {
  const DebtReceiptSheet({
    super.key,
    required this.debt,
    this.storeName,
    this.storePhone,
  });

  final DebtRecord debt;
  final String? storeName;
  final String? storePhone;

  static Future<void> show(
    BuildContext context,
    DebtRecord debt, {
    String? storeName,
    String? storePhone,
  }) {
    return showCredModal(
      context: context,
      builder: (_) => DebtReceiptSheet(
        debt: debt,
        storeName: storeName,
        storePhone: storePhone,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final overdue = paymentRepo.isDebtOverdue(debt);
    final phoneFromDebt = debt.customerPhone?.trim();
    final needsLookup =
        (phoneFromDebt == null || phoneFromDebt.isEmpty) && debt.customerId.trim().isNotEmpty;
    final profileAsync = needsLookup ? ref.watch(userProfileByIdProvider(debt.customerId)) : null;
    final resolvedPhone = (phoneFromDebt != null && phoneFromDebt.isNotEmpty)
        ? phoneFromDebt
        : profileAsync?.asData?.value?.phoneNumber?.trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return FutureBuilder<List<PaymentHistoryEntry>>(
          future: debt.id == null ? Future.value([]) : paymentRepo.getPaymentHistory(debt.id!),
          builder: (context, snap) {
            final payments = snap.data ?? [];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Text('Debt Receipt', style: Theme.of(context).textTheme.titleLarge),
                if (storeName != null) ...[
                  const SizedBox(height: 4),
                  Text(storeName!, style: Theme.of(context).textTheme.titleMedium),
                ],
                const SizedBox(height: 16),
                _detailRow('Customer', debt.customerName ?? debt.customerId),
                if (resolvedPhone != null && resolvedPhone.isNotEmpty)
                  _detailRow('Phone', resolvedPhone),
                _detailRow('Total', CurrencyFormatter.format(debt.totalAmount)),
                _detailRow('Remaining', CurrencyFormatter.format(debt.remainingBalance)),
                _detailRow('Status', debt.paymentStatus),
                if (debt.dueDate != null)
                  _detailRow(
                    'Due Date',
                    DateFormatter.format(debt.dueDate!),
                    highlight: overdue,
                  ),
                if (debt.createdAt != null)
                  _detailRow('Created', DateFormatter.formatDateTime(debt.createdAt!)),
                if (overdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: const Text('OVERDUE'),
                      backgroundColor: Colors.red.shade50,
                      labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (debt.items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...debt.items.map((item) {
                    final name = item['product_name'] as String? ??
                        item['name'] as String? ??
                        'Item';
                    final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
                    final price = (item['price'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} x ${CurrencyFormatter.format(price)}'),
                      trailing: Text(CurrencyFormatter.format(qty * price)),
                    );
                  }),
                ],
                const SizedBox(height: 20),
                Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (!snap.hasData)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ))
                else if (payments.isEmpty)
                  const Text('No payments recorded yet.')
                else
                  ...payments.map((p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(CurrencyFormatter.format(p.amount)),
                        subtitle: Text(
                          p.paymentDate != null
                              ? DateFormatter.formatDateTime(p.paymentDate!)
                              : 'Unknown date',
                        ),
                        trailing: Text(p.paidBy ?? 'Store'),
                      )),
                const SizedBox(height: CredTheme.spaceMd),
                ContactStoreButton(
                  phone: storePhone,
                  storeName: storeName,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: highlight ? Colors.red : null),
            ),
          ),
        ],
      ),
    );
  }
}
