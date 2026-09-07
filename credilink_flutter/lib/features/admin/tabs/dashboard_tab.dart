import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/common/info_banner.dart';
import '../../../shared/widgets/layout/cred_fade_in.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';

class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DashboardData> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    final platform = await repo.getPlatformStats();
    final financial = await repo.getFinancialStats();
    final today = await repo.getTodayActivity();
    final debtHealth = await repo.getDebtHealth();
    final topStores = await repo.getTopStores();
    final criticalAlerts = await repo.getCriticalAlerts();
    return _DashboardData(
      platform: platform,
      financial: financial,
      today: today,
      debtHealth: debtHealth,
      topStores: topStores,
      criticalAlerts: criticalAlerts,
    );
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
        final platform = data.platform;
        final financial = data.financial;
        final today = data.today;
        final debtHealth = data.debtHealth;
        final topStores = data.topStores;
        final criticalAlerts = data.criticalAlerts;

        return CredTabPageLayout(
          onRefresh: _refresh,
          children: [
            const SizedBox(height: CredTheme.spaceMd),
            if (criticalAlerts.isNotEmpty) ...[
              CredFadeIn(
                child: CredSection(
                  title: 'Critical Alerts',
                  child: Column(
                    children: [
                      for (var i = 0; i < criticalAlerts.length; i++) ...[
                        if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                        CredSurfaceTile(
                          emphasized: true,
                          leading: const Icon(Icons.warning_amber_rounded, color: CredTheme.danger),
                          title: Text(criticalAlerts[i]['message'] as String? ?? 'Alert'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CredTheme.spaceLg),
            ],
            CredFadeIn(
              delay: criticalAlerts.isNotEmpty
                  ? const Duration(milliseconds: 40)
                  : Duration.zero,
              child: CredSection(
                title: 'Platform Overview',
                subtitle: 'Users and stores across CrediLink',
                child: CredMetricGrid(
                  metrics: [
                    CredMetricCard(
                      label: 'Total Users',
                      value: '${platform['totalUsers']}',
                      icon: Icons.people,
                      accentColor: CredTheme.info,
                    ),
                    CredMetricCard(
                      label: 'Total Stores',
                      value: '${platform['totalStores']}',
                      icon: Icons.store,
                      accentColor: CredTheme.primary,
                    ),
                    CredMetricCard(
                      label: 'Active Stores',
                      value: '${platform['activeStores']}',
                      icon: Icons.storefront,
                      accentColor: CredTheme.success,
                    ),
                    CredMetricCard(
                      label: 'Employees',
                      value: '${platform['totalEmployees']}',
                      icon: Icons.badge,
                      accentColor: CredTheme.warning,
                    ),
                    CredMetricCard(
                      label: 'Customers',
                      value: '${platform['totalCustomers']}',
                      icon: Icons.person,
                      accentColor: CredTheme.info,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredFadeIn(
              delay: const Duration(milliseconds: 80),
              child: CredSection(
                title: 'Financial Overview',
                child: Column(
                  children: [
                    CredMetricCard(
                      label: 'Total Revenue',
                      value: CurrencyFormatter.format(financial['totalRevenue'] ?? 0),
                      icon: Icons.payments,
                      accentColor: CredTheme.success,
                      style: CredMetricStyle.featured,
                    ),
                    const SizedBox(height: CredTheme.spaceSm),
                    CredMetricGrid(
                      metrics: [
                        CredMetricCard(
                          label: 'Outstanding Debt',
                          value: CurrencyFormatter.format(financial['totalOutstanding'] ?? 0),
                          icon: Icons.account_balance,
                          accentColor: CredTheme.danger,
                        ),
                        CredMetricCard(
                          label: 'Avg Store Revenue',
                          value: CurrencyFormatter.format(financial['avgStoreRevenue'] ?? 0),
                          icon: Icons.trending_up,
                          accentColor: CredTheme.info,
                        ),
                        CredMetricCard(
                          label: 'Transactions',
                          value: '${financial['totalTransactions']}',
                          icon: Icons.receipt_long,
                          accentColor: CredTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Debt Portfolio Aging',
              child: Column(
                children: [
                  _AgingRow(
                    label: 'Current',
                    amount: debtHealth['current'] ?? 0,
                    color: CredTheme.success,
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  _AgingRow(
                    label: '30 days overdue',
                    amount: debtHealth['overdue30'] ?? 0,
                    color: CredTheme.warning,
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  _AgingRow(
                    label: '60 days overdue',
                    amount: debtHealth['overdue60'] ?? 0,
                    color: CredTheme.danger.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  _AgingRow(
                    label: '90+ days overdue',
                    amount: debtHealth['overdue90'] ?? 0,
                    color: CredTheme.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: "Today's Activity",
              subtitle: 'Platform-wide today',
              child: CredMetricGrid(
                metrics: [
                  CredMetricCard(
                    label: 'Sales',
                    value: '${today['transactions']}',
                    icon: Icons.point_of_sale,
                    accentColor: CredTheme.success,
                  ),
                  CredMetricCard(
                    label: 'New Debts',
                    value: '${today['newDebts']}',
                    icon: Icons.receipt_long,
                    accentColor: CredTheme.info,
                  ),
                  CredMetricCard(
                    label: 'Payments',
                    value: '${today['payments']}',
                    icon: Icons.payments,
                    accentColor: CredTheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Top Stores',
              child: topStores.isEmpty
                  ? const InfoBanner(message: 'No store performance data yet.')
                  : Column(
                      children: [
                        for (var i = 0; i < topStores.length; i++) ...[
                          if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                          CredSurfaceTile(
                            leading: CredAvatar(name: '${i + 1}'),
                            title: Text(topStores[i]['name'] as String? ?? 'Unknown'),
                            subtitle: Text('${topStores[i]['employeeCount'] ?? 0} employees'),
                            trailing: Text(
                              CurrencyFormatter.format(topStores[i]['revenue'] ?? 0),
                              style: CredTheme.listAmountStyle(context),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Quick Links',
              child: CredQuickActionGrid(
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
            ),
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
  });

  final Map<String, int> platform;
  final Map<String, num> financial;
  final Map<String, int> today;
  final Map<String, double> debtHealth;
  final List<Map<String, dynamic>> topStores;
  final List<Map<String, dynamic>> criticalAlerts;
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CredSurfaceTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label),
      trailing: Text(
        CurrencyFormatter.format(amount),
        style: CredTheme.listAmountStyle(context),
      ),
    );
  }
}
