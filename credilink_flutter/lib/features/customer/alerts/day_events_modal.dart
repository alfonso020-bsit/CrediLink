import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';

class DayEventsModal extends StatelessWidget {
  const DayEventsModal({
    super.key,
    required this.date,
    required this.debts,
    this.storeNames = const {},
    this.storePhones = const {},
  });

  final DateTime date;
  final List<DebtRecord> debts;
  final Map<String, String> storeNames;
  final Map<String, String> storePhones;

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required List<DebtRecord> debts,
    Map<String, String> storeNames = const {},
    Map<String, String> storePhones = const {},
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DayEventsModal(
        date: date,
        debts: debts,
        storeNames: storeNames,
        storePhones: storePhones,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = debts.where((d) => d.createdAt != null && _sameDay(d.createdAt!, date)).toList();
    final due = debts.where((d) => d.dueDate != null && _sameDay(d.dueDate!, date)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Events on ${DateFormatter.format(date)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (due.isNotEmpty) ...[
              Text('Payments Due', style: Theme.of(context).textTheme.titleMedium),
              ...due.map((debt) => _eventTile(context, debt, 'Due ${CurrencyFormatter.format(debt.remainingBalance)}')),
              const SizedBox(height: 16),
            ],
            if (created.isNotEmpty) ...[
              Text('Debts Created', style: Theme.of(context).textTheme.titleMedium),
              ...created.map((debt) => _eventTile(context, debt, 'Amount ${CurrencyFormatter.format(debt.totalAmount)}')),
            ],
            if (due.isEmpty && created.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No events for this day')),
              ),
          ],
        );
      },
    );
  }

  Widget _eventTile(BuildContext context, DebtRecord debt, String subtitle) {
    final storeName = storeNames[debt.storeOwnerId] ?? 'Store';
    return Card(
      child: ListTile(
        leading: Icon(
          debt.isOverdue ? Icons.warning : Icons.event,
          color: debt.isOverdue ? Colors.red : null,
        ),
        title: Text(storeName),
        subtitle: Text(subtitle),
        onTap: () {
          Navigator.pop(context);
          DebtReceiptSheet.show(
            context,
            debt,
            storeName: storeName,
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
