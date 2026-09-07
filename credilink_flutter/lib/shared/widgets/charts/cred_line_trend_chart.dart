import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/sales_trend.dart';
import '../common/empty_state.dart';

enum CredTrendMetric { revenue, count }

/// Compact line chart for dashboard sales trends.
class CredLineTrendChart extends StatelessWidget {
  const CredLineTrendChart({
    super.key,
    required this.points,
    this.metric = CredTrendMetric.revenue,
    this.height = 200,
    this.seriesLabel,
  });

  final List<SalesTrendPoint> points;
  final CredTrendMetric metric;
  final double height;
  final String? seriesLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const EmptyState(message: 'No sales in this period'),
      );
    }

    final values = points
        .map((p) => metric == CredTrendMetric.revenue ? p.revenue : p.count.toDouble())
        .toList();
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final hasData = values.any((v) => v > 0);

    if (!hasData) {
      return SizedBox(
        height: height,
        child: const EmptyState(message: 'No sales in this period'),
      );
    }

    final top = maxY <= 0 ? 1.0 : maxY * 1.15;
    final labelStep = _labelStep(points.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: top,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: CredTheme.border,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: top / 4,
                    getTitlesWidget: (value, meta) {
                      if (value <= 0 || value >= top) return const SizedBox.shrink();
                      return Text(
                        _shortAxis(value, metric),
                        style: const TextStyle(fontSize: 10, color: CredTheme.subtitleText),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox.shrink();
                      if (i % labelStep != 0 && i != points.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          points[i].label,
                          style: const TextStyle(fontSize: 10, color: CredTheme.subtitleText),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final i = s.x.toInt();
                    final point = (i >= 0 && i < points.length) ? points[i] : null;
                    final label = point?.label ?? '';
                    final text = metric == CredTrendMetric.revenue
                        ? '₱${s.y.toStringAsFixed(s.y >= 100 ? 0 : 2)}'
                        : s.y.toStringAsFixed(0);
                    return LineTooltipItem(
                      '$label\n$text',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), values[i]),
                  ],
                  isCurved: true,
                  color: CredTheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: points.length <= 14,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: 3,
                      color: CredTheme.primary,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: CredTheme.primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (seriesLabel != null) ...[
          const SizedBox(height: CredTheme.spaceXs),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: CredTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                seriesLabel!,
                style: const TextStyle(fontSize: 12, color: CredTheme.subtitleText),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static int _labelStep(int length) {
    if (length <= 7) return 1;
    if (length <= 14) return 2;
    return 5;
  }

  static String _shortAxis(double value, CredTrendMetric metric) {
    if (metric == CredTrendMetric.count) {
      return value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 100) return value.toStringAsFixed(0);
    return value.toStringAsFixed(0);
  }
}
