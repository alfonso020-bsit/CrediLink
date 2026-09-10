import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_fade_in.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';

class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  late Future<_DashboardData> _dataFuture;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DashboardData> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.getPlatformStats(),
      repo.getFinancialStats(),
      repo.getTodayActivity(),
      repo.getDebtHealth(),
      repo.getTopStores(limit: 6),
      repo.getCriticalAlerts(),
      repo.getRoleDistribution(),
      repo.getPlatformSalesTrend(days: 14),
    ]);

    final data = _DashboardData(
      platform: results[0] as Map<String, int>,
      financial: results[1] as Map<String, num>,
      today: results[2] as Map<String, int>,
      debtHealth: results[3] as Map<String, double>,
      topStores: results[4] as List<Map<String, dynamic>>,
      criticalAlerts: results[5] as List<Map<String, dynamic>>,
      roles: results[6] as Map<String, int>,
      salesTrend: results[7] as List<Map<String, dynamic>>,
    );
    _loadedAt = DateTime.now();
    return data;
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = _load());
    await _dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            title: 'Could not load dashboard',
            message: '${snap.error}',
            action: TextButton(onPressed: _refresh, child: const Text('Retry')),
          );
        }
        final data = snap.data!;

        return CredTabPageLayout(
          onRefresh: _refresh,
          children: [
            CredFadeIn(child: _Header(loadedAt: _loadedAt, onRefresh: _refresh)),
            const SizedBox(height: CredTheme.spaceMd),
            if (data.criticalAlerts.isNotEmpty) ...[
              CredFadeIn(child: _AlertsBanner(alerts: data.criticalAlerts)),
              const SizedBox(height: CredTheme.spaceMd),
            ],
            CredFadeIn(
              delay: const Duration(milliseconds: 40),
              child: _KpiRow(data: data),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredFadeIn(
              delay: const Duration(milliseconds: 80),
              child: _ResponsiveRow(
                left: _Panel(
                  title: 'Sales trend',
                  subtitle: 'Cash revenue · last 14 days',
                  child: _SalesTrendChart(trend: data.salesTrend),
                ),
                right: _Panel(
                  title: 'Debt portfolio',
                  subtitle: 'Aging by overdue bucket',
                  child: _DebtAgingChart(debtHealth: data.debtHealth),
                ),
                leftFlex: 3,
                rightFlex: 2,
              ),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredFadeIn(
              delay: const Duration(milliseconds: 120),
              child: _ResponsiveRow(
                left: _Panel(
                  title: 'User mix',
                  subtitle: 'Roles across the platform',
                  child: _RoleMixChart(roles: data.roles),
                ),
                right: _Panel(
                  title: "Today's pulse",
                  subtitle: 'Live platform activity',
                  trailing: TextButton(
                    onPressed: () => context.go('/admin/tab4'),
                    child: const Text('Analytics'),
                  ),
                  child: _TodayAndStores(data: data),
                ),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: CredTheme.spaceLg),
              CredQuickActionGrid(
                actions: [
                  CredQuickAction(
                    label: 'Stores',
                    icon: Icons.store,
                    onPressed: () => context.go('/admin/tab2'),
                  ),
                  CredQuickAction(
                    label: 'Users',
                    icon: Icons.people,
                    onPressed: () => context.go('/admin/tab3'),
                  ),
                  CredQuickAction(
                    label: 'Analytics',
                    icon: Icons.analytics,
                    onPressed: () => context.go('/admin/tab4'),
                  ),
                  CredQuickAction(
                    label: 'System',
                    icon: Icons.settings,
                    onPressed: () => context.go('/admin/tab5'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: CredTheme.spaceMd),
          ],
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.platform,
    required this.financial,
    required this.today,
    required this.debtHealth,
    required this.topStores,
    required this.criticalAlerts,
    required this.roles,
    required this.salesTrend,
  });

  final Map<String, int> platform;
  final Map<String, num> financial;
  final Map<String, int> today;
  final Map<String, double> debtHealth;
  final List<Map<String, dynamic>> topStores;
  final List<Map<String, dynamic>> criticalAlerts;
  final Map<String, int> roles;
  final List<Map<String, dynamic>> salesTrend;
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, this.loadedAt});

  final DateTime? loadedAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final timeLabel = loadedAt == null
        ? 'Loading…'
        : 'Updated ${DateFormat.jm().format(loadedAt!)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform overview',
                style: CredTheme.pageTitle(context).copyWith(fontSize: kIsWeb ? 24 : 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Stores, users, revenue, and debt health at a glance.',
                style: CredTheme.bodyMutedStyle(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: CredTheme.spaceMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(height: 6),
            Text(timeLabel, style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.alerts});

  final List<Map<String, dynamic>> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CredTheme.spaceMd),
      decoration: BoxDecoration(
        color: CredTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        border: Border.all(color: CredTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: CredTheme.danger, size: 20),
              SizedBox(width: 8),
              Text(
                'Attention needed',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: CredTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                alert['message'] as String? ?? 'Alert',
                style: CredTheme.bodyMutedStyle(context).copyWith(color: CredTheme.titleText),
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiSpec(
        label: 'Total users',
        value: '${data.platform['totalUsers'] ?? 0}',
        hint: '${data.platform['totalCustomers'] ?? 0} customers',
        icon: Icons.people_outline,
        color: CredTheme.info,
      ),
      _KpiSpec(
        label: 'Active stores',
        value: '${data.platform['activeStores'] ?? 0}',
        hint: 'of ${data.platform['totalStores'] ?? 0} total',
        icon: Icons.storefront_outlined,
        color: CredTheme.primary,
      ),
      _KpiSpec(
        label: 'Total revenue',
        value: CurrencyFormatter.format(data.financial['totalRevenue'] ?? 0),
        hint: '${data.financial['totalTransactions'] ?? 0} txns',
        icon: Icons.payments_outlined,
        color: CredTheme.success,
      ),
      _KpiSpec(
        label: 'Outstanding debt',
        value: CurrencyFormatter.format(data.financial['totalOutstanding'] ?? 0),
        hint: 'Across all stores',
        icon: Icons.account_balance_outlined,
        color: CredTheme.danger,
      ),
      _KpiSpec(
        label: "Today's sales",
        value: '${data.today['transactions'] ?? 0}',
        hint:
            '${data.today['newDebts'] ?? 0} debts · ${data.today['payments'] ?? 0} payments',
        icon: Icons.bolt_outlined,
        color: CredTheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return const SizedBox(height: 120);
        }
        final columns = width >= 1100
            ? 5
            : width >= 820
                ? 3
                : width >= 520
                    ? 2
                    : 1;
        final gap = CredTheme.spaceSm;
        final itemWidth = ((width - gap * (columns - 1)) / columns).clamp(0.0, width);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _KpiCard(spec: item),
              ),
          ],
        );
      },
    );
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.spec});

  final _KpiSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CredTheme.spaceMd),
      decoration: BoxDecoration(
        color: CredTheme.cardBackground,
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        border: Border.all(color: CredTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(spec.icon, size: 20, color: spec.color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: CredTheme.spaceMd),
          Text(
            spec.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: CredTheme.subtitleText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CredTheme.metricValue(context).copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            spec.hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CredTheme.spaceMd),
      decoration: BoxDecoration(
        color: CredTheme.cardBackground,
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        border: Border.all(color: CredTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CredTheme.sectionTitle(context)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: CredTheme.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: CredTheme.spaceMd),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: CredTheme.spaceMd),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.trend});

  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const SizedBox(height: 240, child: EmptyState(message: 'No sales data yet'));
    }

    final revenues = trend.map((e) => (e['revenue'] as num?)?.toDouble() ?? 0).toList();
    final maxY = revenues.fold<double>(0, (m, v) => v > m ? v : m);
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;
    final hasData = revenues.any((v) => v > 0);

    if (!hasData) {
      return const SizedBox(height: 240, child: EmptyState(message: 'No cash sales in this period'));
    }

    final periodRevenue = revenues.fold<double>(0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CurrencyFormatter.format(periodRevenue),
          style: CredTheme.metricValue(context).copyWith(fontSize: 20),
        ),
        Text(
          'Period total',
          style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
        ),
        const SizedBox(height: CredTheme.spaceMd),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (trend.length - 1).toDouble(),
              minY: 0,
              maxY: top,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) => const FlLine(
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
                    reservedSize: 40,
                    interval: top / 4,
                    getTitlesWidget: (value, meta) {
                      if (value <= 0 || value >= top) return const SizedBox.shrink();
                      return Text(
                        value >= 1000
                            ? '${(value / 1000).toStringAsFixed(1)}k'
                            : value.toStringAsFixed(0),
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
                      if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                      if (i % 2 != 0 && i != trend.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          trend[i]['label'] as String? ?? '',
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
                    final label = (i >= 0 && i < trend.length)
                        ? (trend[i]['label'] as String? ?? '')
                        : '';
                    return LineTooltipItem(
                      '$label\n${CurrencyFormatter.format(s.y)}',
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
                    for (var i = 0; i < trend.length; i++)
                      FlSpot(i.toDouble(), revenues[i]),
                  ],
                  isCurved: true,
                  color: CredTheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: trend.length <= 14,
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
      ],
    );
  }
}

class _DebtAgingChart extends StatelessWidget {
  const _DebtAgingChart({required this.debtHealth});

  final Map<String, double> debtHealth;

  static const _buckets = [
    ('Current', 'current', CredTheme.success),
    ('1–30 days', 'overdue30', CredTheme.warning),
    ('31–60 days', 'overdue60', Color(0xFFEA580C)),
    ('61+ days', 'overdue90', CredTheme.danger),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _buckets.fold<double>(
      0,
      (s, b) => s + (debtHealth[b.$2] ?? 0),
    );

    if (total <= 0) {
      return const SizedBox(height: 240, child: EmptyState(message: 'No outstanding debt'));
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (final b in _buckets)
                  PieChartSectionData(
                    value: debtHealth[b.$2] ?? 0,
                    color: b.$3,
                    radius: 40,
                    title: '',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CredTheme.spaceSm),
        Text(
          CurrencyFormatter.format(total),
          style: CredTheme.metricValue(context).copyWith(fontSize: 18),
        ),
        Text(
          'Total outstanding',
          style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
        ),
        const SizedBox(height: CredTheme.spaceMd),
        for (final b in _buckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: b.$3, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.$1,
                    style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(debtHealth[b.$2] ?? 0),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CredTheme.titleText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RoleMixChart extends StatelessWidget {
  const _RoleMixChart({required this.roles});

  final Map<String, int> roles;

  static const _colors = [
    CredTheme.primary,
    CredTheme.warning,
    CredTheme.success,
    CredTheme.info,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = roles.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    if (total == 0) {
      return const SizedBox(height: 220, child: EmptyState(message: 'No users yet'));
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: _colors[i % _colors.length],
                      radius: 48,
                      title: '${(entries[i].value / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: CredTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${entries[i].value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: CredTheme.titleText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayAndStores extends StatelessWidget {
  const _TodayAndStores({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    final stores = data.topStores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Cash sales',
                value: '${today['transactions'] ?? 0}',
                color: CredTheme.success,
              ),
            ),
            const SizedBox(width: CredTheme.spaceSm),
            Expanded(
              child: _MiniStat(
                label: 'New debts',
                value: '${today['newDebts'] ?? 0}',
                color: CredTheme.info,
              ),
            ),
            const SizedBox(width: CredTheme.spaceSm),
            Expanded(
              child: _MiniStat(
                label: 'Payments',
                value: '${today['payments'] ?? 0}',
                color: CredTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: CredTheme.spaceMd),
        Row(
          children: [
            Text('Top stores', style: CredTheme.sectionTitle(context).copyWith(fontSize: 13)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/admin/tab2'),
              child: const Text('View all'),
            ),
          ],
        ),
        if (stores.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CredTheme.spaceMd),
            child: EmptyState(message: 'No store performance yet'),
          )
        else
          ...[
            for (var i = 0; i < stores.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: CredTheme.border),
              InkWell(
                onTap: () => context.go('/admin/tab2'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: CredTheme.subtitleText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stores[i]['name'] as String? ?? 'Store',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: CredTheme.titleText,
                              ),
                            ),
                            Text(
                              '${stores[i]['employeeCount'] ?? 0} employees',
                              style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(stores[i]['revenue'] ?? 0),
                        style: CredTheme.listAmountStyle(context).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
