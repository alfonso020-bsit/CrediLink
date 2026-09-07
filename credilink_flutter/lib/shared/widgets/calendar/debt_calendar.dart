import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../models/debt_record.dart';

class DebtCalendarDay {
  const DebtCalendarDay({
    required this.date,
    required this.debts,
    this.isCurrentMonth = true,
  });

  final DateTime? date;
  final List<DebtRecord> debts;
  final bool isCurrentMonth;

  bool get hasEvents => debts.isNotEmpty;
  bool get hasOverdue => debts.any((d) => d.isOverdue && !d.isPaid);
  bool get hasDue => debts.any((d) => !d.isPaid && d.dueDate != null);
}

class DebtCalendar extends StatefulWidget {
  const DebtCalendar({
    super.key,
    required this.debts,
    this.onDebtTap,
    this.onDayTap,
  });

  final List<DebtRecord> debts;
  final void Function(DebtRecord debt)? onDebtTap;
  final void Function(DateTime day, List<DebtRecord> debts)? onDayTap;

  @override
  State<DebtCalendar> createState() => _DebtCalendarState();
}

class _DebtCalendarState extends State<DebtCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = widget.debts.where((d) => d.isOverdue && !d.isPaid).length;
    final pending = widget.debts.where((d) => !d.isPaid && !d.isOverdue).length;
    final days = _buildMonthDays(_visibleMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debt Calendar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(context, '$overdue Overdue', Colors.red),
                const SizedBox(width: 8),
                _chip(context, '$pending Pending', Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('W', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('F', style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
            const SizedBox(height: 8),
            ..._chunkDays(days).map((week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: week.map((day) {
                    return Expanded(child: _dayCell(context, day));
                  }).toList(),
                ),
              );
            }),
            const SizedBox(height: 12),
            ...widget.debts.take(5).map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.customerName ?? 'Debt'),
                  subtitle: Text(CurrencyFormatter.format(d.remainingBalance)),
                  trailing: Text(d.paymentStatus),
                  onTap: () => widget.onDebtTap?.call(d),
                )),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DebtCalendarDay day) {
    if (day.date == null) return const SizedBox(height: 36);

    final isToday = _isSameDay(day.date!, DateTime.now());
    final color = day.hasOverdue
        ? Colors.red
        : day.hasDue
            ? Colors.orange
            : day.hasEvents
                ? Theme.of(context).colorScheme.primary
                : null;

    return InkWell(
      onTap: day.debts.isEmpty || widget.onDayTap == null
          ? null
          : () => widget.onDayTap!(day.date!, day.debts),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? Theme.of(context).colorScheme.primaryContainer
              : color?.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.date!.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: day.isCurrentMonth ? null : Colors.grey,
              ),
            ),
            if (day.hasEvents)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  List<DebtCalendarDay> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final days = <DebtCalendarDay>[];

    for (var i = 0; i < 42; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final dayDebts = widget.debts.where((debt) {
        final due = debt.dueDate;
        final created = debt.createdAt;
        return (due != null && _isSameDay(due, date)) ||
            (created != null && _isSameDay(created, date));
      }).toList();

      days.add(DebtCalendarDay(
        date: date,
        debts: dayDebts,
        isCurrentMonth: date.month == month.month,
      ));
    }
    return days;
  }

  List<List<DebtCalendarDay>> _chunkDays(List<DebtCalendarDay> days) {
    final weeks = <List<DebtCalendarDay>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7));
    }
    return weeks;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }
}
