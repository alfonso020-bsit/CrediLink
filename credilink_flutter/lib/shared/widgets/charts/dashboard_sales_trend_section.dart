import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/sales_trend.dart';
import '../../../models/sale_record.dart';
import '../../../repositories/repositories.dart';
import '../common/cred_async_view.dart';
import '../filters/cred_segmented_filter.dart';
import '../layout/cred_section.dart';
import 'cred_line_trend_chart.dart';

/// Dashboard “Sales trend” block with 7/30 day toggle.
class DashboardSalesTrendSection extends ConsumerStatefulWidget {
  const DashboardSalesTrendSection({
    super.key,
    required this.storeOwnerId,
    required this.title,
    required this.metric,
    required this.seriesLabel,
    this.subtitle,
    this.employeeId,
  });

  final String storeOwnerId;
  final String? employeeId;
  final String title;
  final String? subtitle;
  final CredTrendMetric metric;
  final String seriesLabel;

  @override
  ConsumerState<DashboardSalesTrendSection> createState() =>
      _DashboardSalesTrendSectionState();
}

class _DashboardSalesTrendSectionState extends ConsumerState<DashboardSalesTrendSection> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(storeSalesProvider(widget.storeOwnerId));

    return CredSection(
      title: widget.title,
      subtitle: widget.subtitle ?? 'Last $_days days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CredSegmentedFilter<int>(
            options: const [7, 30],
            selected: _days,
            onChanged: (d) => setState(() => _days = d),
            labelBuilder: (d) => '$d days',
          ),
          const SizedBox(height: CredTheme.spaceMd),
          CredAsyncView<List<SaleRecord>>(
            asyncValue: salesAsync,
            emptyMessage: 'No sales yet',
            onRetry: () => ref.invalidate(storeSalesProvider(widget.storeOwnerId)),
            builder: (sales) {
              final points = buildSalesTrend(
                sales: sales,
                days: _days,
                employeeId: widget.employeeId,
              );
              return CredLineTrendChart(
                points: points,
                metric: widget.metric,
                seriesLabel: widget.seriesLabel,
              );
            },
          ),
        ],
      ),
    );
  }
}
