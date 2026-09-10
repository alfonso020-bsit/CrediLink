import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../layout/cred_modal.dart';
import '../layout/cred_sheet_scaffold.dart';
import '../receipts/payment_sheet.dart';

/// Bottom sheet listing debts due/created on a calendar day.
class DebtDaySheet extends StatelessWidget {
  const DebtDaySheet({
    super.key,
    required this.date,
    required this.debts,
    this.titleForDebt,
    this.subtitleForDebt,
    this.storeNames = const {},
    this.storePhones = const {},
    this.viewAllLabel,
    this.onViewAll,
  });

  final DateTime date;
  final List<DebtRecord> debts;
  /// Defaults to customer name, then store name map, then "Debt".
  final String Function(DebtRecord debt)? titleForDebt;
  final String Function(DebtRecord debt)? subtitleForDebt;
  final Map<String, String> storeNames;
  final Map<String, String> storePhones;
  final String? viewAllLabel;
  final VoidCallback? onViewAll;

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required List<DebtRecord> debts,
    String Function(DebtRecord debt)? titleForDebt,
    String Function(DebtRecord debt)? subtitleForDebt,
    Map<String, String> storeNames = const {},
    Map<String, String> storePhones = const {},
    String? viewAllLabel,
    VoidCallback? onViewAll,
  }) {
    return showCredModal(
      context: context,
      builder: (_) => DebtDaySheet(
        date: date,
        debts: debts,
        titleForDebt: titleForDebt,
        subtitleForDebt: subtitleForDebt,
        storeNames: storeNames,
        storePhones: storePhones,
        viewAllLabel: viewAllLabel,
        onViewAll: onViewAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final due = debts.where((d) => d.dueDate != null && _sameDay(d.dueDate!, date)).toList();
    final created =
        debts.where((d) => d.createdAt != null && _sameDay(d.createdAt!, date)).toList();

    return CredSheetScaffold(
      title: 'Debts on ${DateFormatter.format(date)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (due.isNotEmpty) ...[
            Text('Payments due', style: CredTheme.sectionTitle(context)),
            const SizedBox(height: CredTheme.spaceXs),
            ...due.map((debt) => _tile(context, debt, isDue: true)),
            const SizedBox(height: CredTheme.spaceMd),
          ],
          if (created.isNotEmpty) ...[
            Text('Debts created', style: CredTheme.sectionTitle(context)),
            const SizedBox(height: CredTheme.spaceXs),
            ...created.map((debt) => _tile(context, debt, isDue: false)),
            const SizedBox(height: CredTheme.spaceMd),
          ],
          if (due.isEmpty && created.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
              child: Center(child: Text('No debts for this day')),
            ),
          if (viewAllLabel != null && onViewAll != null) ...[
            const SizedBox(height: CredTheme.spaceSm),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onViewAll!();
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(viewAllLabel!),
            ),
          ],
        ],
      ),
    );
  }

  String _title(DebtRecord debt) {
    if (titleForDebt != null) return titleForDebt!(debt);
    final customer = debt.customerName?.trim();
    if (customer != null && customer.isNotEmpty) return customer;
    final store = storeNames[debt.storeOwnerId];
    if (store != null && store.isNotEmpty) return store;
    return 'Debt';
  }

  String _subtitle(DebtRecord debt, {required bool isDue}) {
    if (subtitleForDebt != null) return subtitleForDebt!(debt);
    if (isDue) {
      return 'Due ${CurrencyFormatter.format(debt.remainingBalance)} · ${debt.paymentStatus}';
    }
    return 'Amount ${CurrencyFormatter.format(debt.totalAmount)} · ${debt.paymentStatus}';
  }

  Widget _tile(BuildContext context, DebtRecord debt, {required bool isDue}) {
    return Card(
      margin: const EdgeInsets.only(bottom: CredTheme.spaceXs),
      child: ListTile(
        leading: Icon(
          debt.isOverdue ? Icons.warning_amber : Icons.event,
          color: debt.isOverdue ? CredTheme.danger : CredTheme.primary,
        ),
        title: Text(_title(debt)),
        subtitle: Text(_subtitle(debt, isDue: isDue)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          DebtReceiptSheet.show(
            context,
            debt,
            storeName: storeNames[debt.storeOwnerId],
            storePhone: storePhones[debt.storeOwnerId],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
