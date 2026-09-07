import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/debt_record.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/calendar/debt_calendar.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/receipts/payment_sheet.dart';
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
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final bundleAsync = ref.watch(currentCustomerDebtsBundleProvider);

    return CredAsyncView<
        ({
          List<DebtRecord> debts,
          Map<String, StoreProfile> stores,
          Map<String, String> storePhones,
        })>(
      asyncValue: bundleAsync,
      emptyMessage: 'No financial alerts',
      onRetry: () => _invalidateBundle(),
      builder: (bundle) {
        final debts = bundle.debts;
        final stores = bundle.stores;
        final storeNames = {
          for (final entry in stores.entries) entry.key: entry.value.displayName,
        };
        final storePhones = bundle.storePhones;

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
                storeImage: stores[debt.storeOwnerId]?.storeImage,
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
                storeImage: stores[debt.storeOwnerId]?.storeImage,
                storePhone: storePhones[debt.storeOwnerId],
                title: 'Payment due at ${storeNames[debt.storeOwnerId] ?? 'Store'}',
              ),
            )
            .where((alert) => !_dismissedAlertIds.contains(alert.id))
            .toList();

        final visibleAlerts = [...overdueAlerts, ...upcomingAlerts];
        final unreadCount =
            visibleAlerts.where((alert) => !_readAlertIds.contains(alert.id)).length;

        return CredTabPageLayout(
          onRefresh: () async {
            _invalidateBundle();
            await ref.read(currentCustomerDebtsBundleProvider.future);
          },
          children: [
            if (unreadCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    for (final alert in visibleAlerts) {
                      _readAlertIds.add(alert.id);
                    }
                  }),
                  child: Text('Mark all read ($unreadCount)'),
                ),
              ),
            if (visibleAlerts.isEmpty)
              const EmptyState(
                title: 'No alerts',
                message: 'No financial alerts',
                icon: Icons.notifications_off,
              ),
            if (overdueAlerts.isNotEmpty)
              CredSection(
                title: 'Overdue Debts',
                child: Column(
                  children: [
                    for (var i = 0; i < overdueAlerts.length; i++) ...[
                      if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                      _AlertCard(
                        alert: overdueAlerts[i],
                        paymentRepo: paymentRepo,
                        isRead: _readAlertIds.contains(overdueAlerts[i].id),
                        onOpen: () => _openDebtDetail(overdueAlerts[i]),
                        onDismiss: () =>
                            setState(() => _dismissedAlertIds.add(overdueAlerts[i].id)),
                        onMarkRead: () =>
                            setState(() => _readAlertIds.add(overdueAlerts[i].id)),
                      ),
                    ],
                  ],
                ),
              ),
            if (upcomingAlerts.isNotEmpty) ...[
              if (overdueAlerts.isNotEmpty) const SizedBox(height: CredTheme.spaceMd),
              CredSection(
                title: 'Upcoming Due Dates',
                child: Column(
                  children: [
                    for (var i = 0; i < upcomingAlerts.length; i++) ...[
                      if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                      _AlertCard(
                        alert: upcomingAlerts[i],
                        paymentRepo: paymentRepo,
                        isRead: _readAlertIds.contains(upcomingAlerts[i].id),
                        onOpen: () => _openDebtDetail(upcomingAlerts[i]),
                        onDismiss: () =>
                            setState(() => _dismissedAlertIds.add(upcomingAlerts[i].id)),
                        onMarkRead: () =>
                            setState(() => _readAlertIds.add(upcomingAlerts[i].id)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Debt calendar',
              subtitle: 'Tap a day for due items',
              child: DebtCalendar(
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
            ),
          ],
        );
      },
    );
  }

  void _invalidateBundle() {
    final profile = ref.read(currentProfileProvider).value;
    if (profile != null) {
      ref.invalidate(customerDebtsProvider(profile.id));
    }
    ref.invalidate(currentCustomerDebtsBundleProvider);
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
}

class _AlertItem {
  const _AlertItem({
    required this.id,
    required this.debt,
    required this.title,
    this.storeName,
    this.storeImage,
    this.storePhone,
    this.highlight = false,
  });

  final String id;
  final DebtRecord debt;
  final String title;
  final String? storeName;
  final String? storeImage;
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
    final debt = alert.debt;
    final overdue = paymentRepo.isDebtOverdue(debt);
    final storeName = alert.storeName ?? 'Store';

    return Opacity(
      opacity: isRead ? 0.72 : 1,
      child: CredSurfaceTile(
        emphasized: alert.highlight,
        leading: CredAvatar(name: storeName, imageUrl: alert.storeImage),
        title: Text(
          storeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.format(debt.remainingBalance),
                  style: CredTheme.listAmountStyle(context),
                ),
                const SizedBox(height: 4),
                CredStatusChip.debt(
                  paymentStatus: debt.paymentStatus,
                  isOverdue: overdue,
                  compact: true,
                ),
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
