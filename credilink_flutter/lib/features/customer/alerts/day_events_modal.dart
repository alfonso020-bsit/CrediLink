import 'package:flutter/material.dart';

import '../../../models/debt_record.dart';
import '../../../shared/widgets/calendar/debt_day_sheet.dart';

/// Customer alerts day sheet — delegates to [DebtDaySheet].
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
    return DebtDaySheet.show(
      context,
      date: date,
      debts: debts,
      storeNames: storeNames,
      storePhones: storePhones,
      titleForDebt: (debt) => storeNames[debt.storeOwnerId] ?? 'Store',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DebtDaySheet(
      date: date,
      debts: debts,
      storeNames: storeNames,
      storePhones: storePhones,
      titleForDebt: (debt) => storeNames[debt.storeOwnerId] ?? 'Store',
    );
  }
}
