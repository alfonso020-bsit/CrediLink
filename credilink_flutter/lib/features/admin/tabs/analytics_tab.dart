import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';

class AdminAnalyticsTab extends ConsumerStatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  ConsumerState<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends ConsumerState<AdminAnalyticsTab> {
  int _days = 7;
  late Future<_AnalyticsData> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _load();
  }

  Future<_AnalyticsData> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    final roles = await repo.getRoleDistribution();
    final trend = await repo.getRegistrationTrend(days: _days);
    final financial = await repo.getFinancialStats();
    return _AnalyticsData(roles: roles, trend: trend, financial: financial);
  }

  Future<void> _refresh() async {
    setState(() => _analyticsFuture = _load());
    await _analyticsFuture;
  }

  void _setDays(int days) {
    setState(() {
      _days = days;
      _analyticsFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _analyticsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            message: '${snap.error}',
            action: TextButton(onPressed: _refresh, child: const Text('Retry')),
          );
        }
        final data = snap.data!;
        final roles = data.roles;
        final trend = data.trend;
        final financial = data.financial;
        final totalRoles = roles.values.fold<int>(0, (s, v) => s + v);

        return CredTabPageLayout(
          onRefresh: _refresh,
          children: [
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Financial Snapshot',
              child: CredMetricGrid(
                metrics: [
                  CredMetricCard(
                    label: 'Total Revenue',
                    value: CurrencyFormatter.format(financial['totalRevenue'] ?? 0),
                    icon: Icons.payments,
                    accentColor: CredTheme.success,
                  ),
                  CredMetricCard(
                    label: 'Outstanding Debt',
                    value: CurrencyFormatter.format(financial['totalOutstanding'] ?? 0),
                    icon: Icons.account_balance,
                    accentColor: CredTheme.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Role Distribution',
              subtitle: totalRoles == 0 ? null : '$totalRoles users',
              child: totalRoles == 0
                  ? const EmptyState(message: 'No user data')
                  : SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 32,
                                sections: _roleSections(roles, totalRoles),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < roles.entries.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _roleColors[i % _roleColors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${roles.entries.elementAt(i).key}: '
                                            '${roles.entries.elementAt(i).value} '
                                            '(${(roles.entries.elementAt(i).value / totalRoles * 100).toStringAsFixed(1)}%)',
                                            style: CredTheme.bodyMutedStyle(context)
                                                .copyWith(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Registration Trends',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CredSegmentedFilter<int>(
                    options: const [7, 30],
                    selected: _days,
                    onChanged: _setDays,
                    labelBuilder: (d) => '$d days',
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: CredTheme.border,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= trend.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    trend[i]['label'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: CredTheme.subtitleText,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < trend.length; i++)
                                FlSpot(i.toDouble(), (trend[i]['users'] as int).toDouble()),
                            ],
                            isCurved: true,
                            color: CredTheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < trend.length; i++)
                                FlSpot(i.toDouble(), (trend[i]['stores'] as int).toDouble()),
                            ],
                            isCurved: true,
                            color: CredTheme.warning,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  const Row(
                    children: [
                      _LegendDot(color: CredTheme.primary, label: 'Users'),
                      SizedBox(width: CredTheme.spaceMd),
                      _LegendDot(color: CredTheme.warning, label: 'Stores'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static const _roleColors = [
    CredTheme.primary,
    CredTheme.warning,
    CredTheme.success,
    CredTheme.info,
  ];

  List<PieChartSectionData> _roleSections(Map<String, int> roles, int total) {
    var i = 0;
    return roles.entries.map((e) {
      final color = _roleColors[i % _roleColors.length];
      i++;
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        color: color,
        radius: 56,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.roles,
    required this.trend,
    required this.financial,
  });

  final Map<String, int> roles;
  final List<Map<String, dynamic>> trend;
  final Map<String, num> financial;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12)),
      ],
    );
  }
}
