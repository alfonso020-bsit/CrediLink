import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/common/info_banner.dart';
import '../../../shared/widgets/common/stat_card.dart';

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
            message: '$snap.error',
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

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (criticalAlerts.isNotEmpty) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Critical Alerts',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final alert in criticalAlerts)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              alert['message'] as String? ?? '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Platform Overview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  StatCard(label: 'Total Users', value: '${platform['totalUsers']}', icon: Icons.people),
                  StatCard(label: 'Total Stores', value: '${platform['totalStores']}', icon: Icons.store),
                  StatCard(label: 'Active Stores', value: '${platform['activeStores']}', icon: Icons.storefront),
                  StatCard(label: 'Employees', value: '${platform['totalEmployees']}', icon: Icons.badge),
                  StatCard(label: 'Customers', value: '${platform['totalCustomers']}', icon: Icons.person),
                ],
              ),
              const SizedBox(height: 24),
              Text('Financial Overview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    label: 'Total Revenue',
                    value: CurrencyFormatter.format(financial['totalRevenue'] ?? 0),
                    icon: Icons.payments,
                  ),
                  StatCard(
                    label: 'Outstanding Debt',
                    value: CurrencyFormatter.format(financial['totalOutstanding'] ?? 0),
                    icon: Icons.account_balance,
                  ),
                  StatCard(
                    label: 'Avg Store Revenue',
                    value: CurrencyFormatter.format(financial['avgStoreRevenue'] ?? 0),
                    icon: Icons.trending_up,
                  ),
                  StatCard(
                    label: 'Transactions',
                    value: '${financial['totalTransactions']}',
                    icon: Icons.receipt_long,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Debt Portfolio Aging', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _AgingRow(
                        label: 'Current',
                        amount: debtHealth['current'] ?? 0,
                        color: Colors.green,
                      ),
                      _AgingRow(
                        label: '30 days overdue',
                        amount: debtHealth['overdue30'] ?? 0,
                        color: Colors.orange,
                      ),
                      _AgingRow(
                        label: '60 days overdue',
                        amount: debtHealth['overdue60'] ?? 0,
                        color: Colors.deepOrange,
                      ),
                      _AgingRow(
                        label: '90+ days overdue',
                        amount: debtHealth['overdue90'] ?? 0,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Activity", style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _MiniStat(label: 'Sales', value: '${today['transactions']}')),
                          Expanded(child: _MiniStat(label: 'New Debts', value: '${today['newDebts']}')),
                          Expanded(child: _MiniStat(label: 'Payments', value: '${today['payments']}')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Top Stores', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (topStores.isEmpty)
                const InfoBanner(message: 'No store performance data yet.')
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < topStores.length; i++)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text('${i + 1}'),
                          ),
                          title: Text(topStores[i]['name'] as String? ?? 'Unknown'),
                          subtitle: Text('${topStores[i]['employeeCount'] ?? 0} employees'),
                          trailing: Text(
                            CurrencyFormatter.format(topStores[i]['revenue'] ?? 0),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickLinkChip(label: 'Stores', icon: Icons.store, route: '/admin/tab2'),
                  _QuickLinkChip(label: 'Users', icon: Icons.people, route: '/admin/tab3'),
                  _QuickLinkChip(label: 'Analytics', icon: Icons.analytics, route: '/admin/tab4'),
                  _QuickLinkChip(label: 'System', icon: Icons.settings, route: '/admin/tab5'),
                ],
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            CurrencyFormatter.format(amount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  const _QuickLinkChip({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => context.go(route),
    );
  }
}
