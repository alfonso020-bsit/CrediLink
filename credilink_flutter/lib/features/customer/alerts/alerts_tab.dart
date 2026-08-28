import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/calendar/debt_calendar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
import '../customer_helpers.dart';
import '../widgets/debt_status_badge.dart';
import 'day_events_modal.dart';

class CustomerAlertsTab extends ConsumerStatefulWidget {
  const CustomerAlertsTab({super.key});

  @override
  ConsumerState<CustomerAlertsTab> createState() => _CustomerAlertsTabState();
}

class _CustomerAlertsTabState extends ConsumerState<CustomerAlertsTab> {
  final _dismissedAlertIds = <String>{};
  final _readAlertIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);

    return profile.when(
      data: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        return FutureBuilder<
            ({
              List<DebtRecord> debts,
              Map<String, StoreProfile> stores,
              Map<String, String> storePhones,
            })>(
          future: _loadAlertsData(ref, p.id),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final debts = snap.data!.debts;
            final storeNames = {
              for (final entry in snap.data!.stores.entries) entry.key: entry.value.storeName,
            };
            final storePhones = snap.data!.storePhones;

            final overdue = debts.where((d) => paymentRepo.isDebtOverdue(d)).toList();
            final upcoming = debts
                .where((d) => !d.isPaid && !paymentRepo.isDebtOverdue(d) && d.dueDate != null)
                .toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

            final overdueAlerts = overdue
                .map(
                  (debt) => _AlertItem(
                    id: 'overdue-${debt.id}',
                    debt: debt,
                    storeName: storeNames[debt.storeOwnerId],
                    storePhone: storePhones[debt.storeOwnerId],
                    title: 'Overdue debt at ${storeNames[debt.storeOwnerId] ?? 'Store'}',
                    highlight: true,
                  ),
                )
                .where((alert) => !_dismissedAlertIds.contains(alert.id))
                .toList();

            final upcomingAlerts = upcoming
                .take(5)
                .map(
                  (debt) => _AlertItem(
                    id: 'upcoming-${debt.id}',
                    debt: debt,
                    storeName: storeNames[debt.storeOwnerId],
                    storePhone: storePhones[debt.storeOwnerId],
                    title: 'Payment due at ${storeNames[debt.storeOwnerId] ?? 'Store'}',
                  ),
                )
                .where((alert) => !_dismissedAlertIds.contains(alert.id))
                .toList();

            final visibleAlerts = [...overdueAlerts, ...upcomingAlerts];
            final unreadCount =
                visibleAlerts.where((alert) => !_readAlertIds.contains(alert.id)).length;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentProfileProvider);
                setState(() {});
              },
              child: ListView(
                padding: CredTheme.pagePadding,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Financial Alerts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () => setState(() {
                            for (final alert in visibleAlerts) {
                              _readAlertIds.add(alert.id);
                            }
                          }),
                          child: Text('Mark all read ($unreadCount)'),
                        ),
                    ],
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  if (visibleAlerts.isEmpty)
                    const EmptyState(
                      message: 'No financial alerts',
                      icon: Icons.notifications_off,
                    ),
                  if (overdueAlerts.isNotEmpty)
                    CredSection(
                      title: 'Overdue Debts',
                      child: Column(
                        children: overdueAlerts
                            .map(
                              (alert) => _AlertCard(
                                alert: alert,
                                paymentRepo: paymentRepo,
                                isRead: _readAlertIds.contains(alert.id),
                                onOpen: () => _openDebtDetail(alert),
                                onDismiss: () => setState(() => _dismissedAlertIds.add(alert.id)),
                                onMarkRead: () => setState(() => _readAlertIds.add(alert.id)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (upcomingAlerts.isNotEmpty) ...[
                    if (overdueAlerts.isNotEmpty) const SizedBox(height: CredTheme.spaceMd),
                    CredSection(
                      title: 'Upcoming Due Dates',
                      child: Column(
                        children: upcomingAlerts
                            .map(
                              (alert) => _AlertCard(
                                alert: alert,
                                paymentRepo: paymentRepo,
                                isRead: _readAlertIds.contains(alert.id),
                                onOpen: () => _openDebtDetail(alert),
                                onDismiss: () => setState(() => _dismissedAlertIds.add(alert.id)),
                                onMarkRead: () => setState(() => _readAlertIds.add(alert.id)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: CredTheme.spaceMd),
                  DebtCalendar(
                    debts: debts,
                    onDebtTap: (d) => DebtReceiptSheet.show(
                      context,
                      d,
                      storeName: storeNames[d.storeOwnerId],
                      storePhone: storePhones[d.storeOwnerId],
                    ),
                    onDayTap: (day, dayDebts) => DayEventsModal.show(
                      context,
                      date: day,
                      debts: dayDebts,
                      storeNames: storeNames,
                      storePhones: storePhones,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(message: '$e'),
    );
  }

  void _openDebtDetail(_AlertItem alert) {
    setState(() => _readAlertIds.add(alert.id));
    DebtReceiptSheet.show(
      context,
      alert.debt,
      storeName: alert.storeName,
      storePhone: alert.storePhone,
    );
  }

  Future<
      ({
        List<DebtRecord> debts,
        Map<String, StoreProfile> stores,
        Map<String, String> storePhones,
      })> _loadAlertsData(
    WidgetRef ref,
    String customerId,
  ) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final storeRepo = ref.read(storeRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final debts = await paymentRepo.getDebtsByCustomer(customerId);

    final storeIds = debts.map((d) => d.storeOwnerId).toSet();
    final stores = <String, StoreProfile>{};
    for (final id in storeIds) {
      final store = await storeRepo.getStore(id);
      if (store != null) stores[id] = store;
    }
    final storePhones = await CustomerHelpers.loadStorePhones(authRepo, storeIds);

    return (debts: debts, stores: stores, storePhones: storePhones);
  }
}

class _AlertItem {
  const _AlertItem({
    required this.id,
    required this.debt,
    required this.title,
    this.storeName,
    this.storePhone,
    this.highlight = false,
  });

  final String id;
  final DebtRecord debt;
  final String title;
  final String? storeName;
  final String? storePhone;
  final bool highlight;
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.paymentRepo,
    required this.isRead,
    required this.onOpen,
    required this.onDismiss,
    required this.onMarkRead,
  });

  final _AlertItem alert;
  final PaymentRepository paymentRepo;
  final bool isRead;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final cred = CredThemeExtension.of(context);
    final debt = alert.debt;

    return Card(
      margin: const EdgeInsets.only(bottom: CredTheme.spaceXs),
      color: alert.highlight
          ? cred.danger.withValues(alpha: isRead ? 0.04 : 0.08)
          : isRead
              ? CredTheme.scaffoldBackground
              : null,
      child: ListTile(
        leading: Icon(
          alert.highlight ? Icons.warning : Icons.schedule,
          color: alert.highlight ? cred.danger : cred.warning,
        ),
        title: Text(
          alert.storeName ?? 'Store',
          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.w600),
        ),
        subtitle: Text(
          debt.dueDate != null
              ? 'Due ${DateFormatter.format(debt.dueDate!)}'
              : 'Outstanding balance',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(debt.remainingBalance)),
                const SizedBox(height: 4),
                DebtStatusBadge(debt: debt, paymentRepo: paymentRepo),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'read':
                    onMarkRead();
                  case 'dismiss':
                    onDismiss();
                }
              },
              itemBuilder: (_) => [
                if (!isRead)
                  const PopupMenuItem(value: 'read', child: Text('Mark as read')),
                const PopupMenuItem(value: 'dismiss', child: Text('Dismiss')),
              ],
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}
