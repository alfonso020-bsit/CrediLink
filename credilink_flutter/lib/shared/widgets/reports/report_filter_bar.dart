import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../filters/cred_search_field.dart';
import '../filters/cred_segmented_filter.dart';

enum ReportPeriod { today, week, month, custom }

class ReportFilterBar extends StatefulWidget {
  const ReportFilterBar({
    super.key,
    this.onPeriodChanged,
    this.onDateRangeChanged,
    this.onSearchChanged,
    this.typeOptions = const ['all', 'cash', 'debt'],
    this.selectedType = 'all',
    this.onTypeChanged,
    this.showSearch = false,
    this.searchHint = 'Search transactions…',
  });

  final ValueChanged<ReportPeriod>? onPeriodChanged;
  final ValueChanged<DateTimeRange>? onDateRangeChanged;
  final ValueChanged<String>? onSearchChanged;
  final List<String> typeOptions;
  final String selectedType;
  final ValueChanged<String>? onTypeChanged;
  final bool showSearch;
  final String searchHint;

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  ReportPeriod _period = ReportPeriod.month;
  DateTimeRange? _customRange;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTimeRange _rangeForPeriod(ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ReportPeriod.today:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
      case ReportPeriod.week:
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today.add(const Duration(days: 1)));
      case ReportPeriod.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today.add(const Duration(days: 1)));
      case ReportPeriod.custom:
        return _customRange ?? DateTimeRange(start: today.subtract(const Duration(days: 30)), end: today.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange ?? _rangeForPeriod(ReportPeriod.month),
    );
    if (picked != null) {
      setState(() {
        _period = ReportPeriod.custom;
        _customRange = picked;
      });
      widget.onPeriodChanged?.call(ReportPeriod.custom);
      widget.onDateRangeChanged?.call(picked);
    }
  }

  void _setPeriod(ReportPeriod period) {
    setState(() => _period = period);
    widget.onPeriodChanged?.call(period);
    widget.onDateRangeChanged?.call(_rangeForPeriod(period));
  }

  String _periodLabel(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.week:
        return 'Week';
      case ReportPeriod.month:
        return 'Month';
      case ReportPeriod.custom:
        if (_customRange != null) {
          final fmt = DateFormat('MMM d');
          return '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}';
        }
        return 'Custom';
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'debt':
        return 'Debt';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CredSegmentedFilter<ReportPeriod>(
            options: const [
              ReportPeriod.today,
              ReportPeriod.week,
              ReportPeriod.month,
              ReportPeriod.custom,
            ],
            selected: _period,
            onChanged: (p) {
              if (p == ReportPeriod.custom) {
                _pickCustomRange();
              } else {
                _setPeriod(p);
              }
            },
            labelBuilder: _periodLabel,
          ),
          if (widget.typeOptions.length > 1) ...[
            const SizedBox(height: 12),
            CredSegmentedFilter<String>(
              options: widget.typeOptions,
              selected: widget.selectedType,
              onChanged: (v) => widget.onTypeChanged?.call(v),
              labelBuilder: _typeLabel,
            ),
          ],
          if (widget.showSearch) ...[
            const SizedBox(height: 12),
            CredSearchField(
              controller: _searchController,
              hint: widget.searchHint,
              onChanged: widget.onSearchChanged,
            ),
          ],
        ],
      ),
    );
  }
}
