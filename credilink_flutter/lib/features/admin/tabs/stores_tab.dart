import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/masquerade/masquerade_provider.dart';
import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../models/store_profile.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_modal.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../widgets/admin_console_table.dart';
import '../widgets/admin_detail_row.dart';

class _StoreListItem {
  const _StoreListItem({
    required this.store,
    required this.ownerStatus,
    required this.ownerName,
    this.ownerProfile,
  });

  final StoreProfile store;
  final String ownerStatus;
  final String ownerName;
  final UserProfile? ownerProfile;

  bool get isActive => ownerStatus == 'active';
}

class AdminStoresTab extends ConsumerStatefulWidget {
  const AdminStoresTab({super.key});

  @override
  ConsumerState<AdminStoresTab> createState() => _AdminStoresTabState();
}

class _AdminStoresTabState extends ConsumerState<AdminStoresTab> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  String? _provinceFilter;
  String? _municipalityFilter;
  late Future<List<_StoreListItem>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_StoreListItem>> _loadStores() async {
    final repo = ref.read(adminRepositoryProvider);
    final stores = await repo.getAllStores();
    final owners = await repo.getUsersByRole('StoreOwner');
    final ownerById = {for (final o in owners) o.id: o};

    return stores.map((store) {
      final owner = ownerById[store.storeOwnerId];
      return _StoreListItem(
        store: store,
        ownerStatus: owner?.status ?? 'inactive',
        ownerName: owner?.fullName ?? store.ownerName ?? 'Unknown',
        ownerProfile: owner,
      );
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _storesFuture = _loadStores());
    await _storesFuture;
  }

  List<String> _provinces(List<_StoreListItem> items) {
    return items
        .map((s) => s.store.province)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _municipalities(List<_StoreListItem> items) {
    var filtered = items;
    if (_provinceFilter != null) {
      filtered = filtered.where((s) => s.store.province == _provinceFilter).toList();
    }
    return filtered
        .map((s) => s.store.municipality)
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<_StoreListItem> _filter(List<_StoreListItem> items) {
    var filtered = items;
    if (_statusFilter == 'active') {
      filtered = filtered.where((s) => s.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      filtered = filtered.where((s) => !s.isActive).toList();
    }
    if (_provinceFilter != null) {
      filtered = filtered.where((s) => s.store.province == _provinceFilter).toList();
    }
    if (_municipalityFilter != null) {
      filtered = filtered.where((s) => s.store.municipality == _municipalityFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((s) {
        final location = [s.store.barangay, s.store.municipality, s.store.province]
            .whereType<String>()
            .join(' ')
            .toLowerCase();
        return s.store.displayName.toLowerCase().contains(q) ||
            s.ownerName.toLowerCase().contains(q) ||
            location.contains(q);
      }).toList();
    }
    return filtered;
  }

  Future<void> _toggleStoreStatus(_StoreListItem item) async {
    final newStatus = item.isActive ? 'inactive' : 'active';
    final action = newStatus == 'active' ? 'activate' : 'deactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Are you sure you want to $action ${item.store.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(authRepositoryProvider).updateUserStatus(item.store.storeOwnerId, newStatus);
    if (!mounted) return;
    CredSnackBar.show(context, 'Store ${newStatus == 'active' ? 'activated' : 'deactivated'}');
    await _refresh();
  }

  Future<void> _deleteStore(_StoreListItem item) async {
    final profileId = item.store.id;
    if (profileId == null || profileId.isEmpty) {
      CredSnackBar.show(context, 'Store profile id missing', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete store?'),
        content: Text(
          'This removes ${item.store.displayName} from the directory and deactivates '
          '${item.ownerName}. Sales and products are not deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CredTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(adminRepositoryProvider).deleteStore(
            storeProfileId: profileId,
            storeOwnerId: item.store.storeOwnerId,
          );
      if (!mounted) return;
      CredSnackBar.show(context, 'Store deleted');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      CredSnackBar.show(context, 'Could not delete store: $e', isError: true);
    }
  }

  Future<void> _startMasquerade(_StoreListItem item) async {
    final owner = item.ownerProfile;
    if (owner == null) {
      CredSnackBar.show(context, 'Store owner profile not found', isError: true);
      return;
    }
    if (!item.isActive) {
      CredSnackBar.show(context, 'Cannot masquerade an inactive store', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Masquerade as store owner?'),
        content: Text(
          'You will view ${item.store.displayName} as ${item.ownerName}. '
          'You stay signed in as Admin. Exit anytime to return to the console.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.read(masqueradeProvider.notifier).start(MasqueradeSession(
      storeOwnerId: owner.id,
      storeName: item.store.displayName,
      ownerProfile: owner,
    ));
    if (!mounted) return;
    context.go('/storeowner/tab1');
  }

  void _showStoreDetail(_StoreListItem item) {
    final store = item.store;
    showCredModal(
      context: context,
      builder: (_) => CredSheetScaffold(
        title: store.displayName,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDetailRow(label: 'Owner', value: item.ownerName),
            AdminDetailRow(label: 'Status', value: item.ownerStatus),
            AdminDetailRow(
              label: 'Location',
              value: [store.barangay, store.municipality, store.province]
                  .whereType<String>()
                  .where((e) => e.isNotEmpty)
                  .join(', '),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            if (item.isActive && item.ownerProfile != null) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startMasquerade(item);
                },
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text('Masquerade'),
              ),
              const SizedBox(height: CredTheme.spaceSm),
            ],
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                _toggleStoreStatus(item);
              },
              child: Text(item.isActive ? 'Deactivate Store' : 'Activate Store'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _deleteStore(item);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Store'),
              style: OutlinedButton.styleFrom(foregroundColor: CredTheme.danger),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StoreListItem>>(
      future: _storesFuture,
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
        final allItems = snap.data ?? [];
        final provinces = _provinces(allItems);
        final municipalities = _municipalities(allItems);
        final filtered = _filter(allItems);
        final activeCount = allItems.where((s) => s.isActive).length;

        return CredTabPageLayout(
          onRefresh: _refresh,
          children: [
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Stores',
              subtitle: '$activeCount active of ${allItems.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CredSearchField(
                    controller: _searchController,
                    hint: 'Search stores…',
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  CredSegmentedFilter<String>(
                    options: const ['all', 'active', 'inactive'],
                    selected: _statusFilter,
                    onChanged: (v) => setState(() => _statusFilter = v),
                    labelBuilder: (v) => switch (v) {
                      'active' => 'Active',
                      'inactive' => 'Inactive',
                      _ => 'All',
                    },
                  ),
                  if (provinces.isNotEmpty) ...[
                    const SizedBox(height: CredTheme.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _provinceFilter,
                            decoration: const InputDecoration(
                              labelText: 'Province',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All provinces', overflow: TextOverflow.ellipsis),
                              ),
                              for (final p in provinces)
                                DropdownMenuItem<String?>(
                                  value: p,
                                  child: Text(p, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              _provinceFilter = v;
                              if (_municipalityFilter != null &&
                                  !municipalities.contains(_municipalityFilter)) {
                                _municipalityFilter = null;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: CredTheme.spaceSm),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _municipalityFilter,
                            decoration: const InputDecoration(
                              labelText: 'Municipality',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'All municipalities',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              for (final m in municipalities)
                                DropdownMenuItem<String?>(
                                  value: m,
                                  child: Text(m, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _municipalityFilter = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Directory',
              subtitle: '${filtered.length} shown',
              child: filtered.isEmpty
                  ? const EmptyState(message: 'No stores found')
                  : AdminConsoleTable.isConsoleLayout
                      ? AdminConsoleTable(
                          columns: const ['Store', 'Owner', 'Location', 'Status', 'Actions'],
                          rows: [
                            for (final item in filtered)
                              AdminConsoleTableRow(
                                onTap: () => _showStoreDetail(item),
                                cells: [
                                  Text(
                                    item.store.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(item.ownerName),
                                  Text(
                                    [
                                      item.store.municipality,
                                      item.store.province,
                                    ].whereType<String>().where((e) => e.isNotEmpty).join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: CredStatusChip.active(
                                      isActive: item.isActive,
                                      compact: true,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _StoreActionIcons(
                                      canMasquerade: item.isActive && item.ownerProfile != null,
                                      isActive: item.isActive,
                                      onMasquerade: () => _startMasquerade(item),
                                      onToggleStatus: () => _toggleStoreStatus(item),
                                      onDelete: () => _deleteStore(item),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                              _StoreTile(
                                item: filtered[i],
                                onTap: () => _showStoreDetail(filtered[i]),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _StoreActionIcons extends StatelessWidget {
  const _StoreActionIcons({
    required this.canMasquerade,
    required this.isActive,
    required this.onMasquerade,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final bool canMasquerade;
  final bool isActive;
  final VoidCallback onMasquerade;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Masquerade',
          onPressed: canMasquerade ? onMasquerade : null,
          icon: const Icon(Icons.face_retouching_natural, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          tooltip: isActive ? 'Deactivate' : 'Activate',
          onPressed: onToggleStatus,
          icon: Icon(
            isActive ? Icons.block_outlined : Icons.check_circle_outline,
            size: 20,
          ),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, size: 20, color: CredTheme.danger),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.item,
    required this.onTap,
  });

  final _StoreListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = [item.store.municipality, item.store.province]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');

    return CredSurfaceTile(
      onTap: onTap,
      leading: CredAvatar(
        name: item.store.displayName,
        imageUrl: item.store.storeImage,
      ),
      title: Text(item.store.displayName),
      subtitle: Text(
        [item.ownerName, location].where((e) => e.isNotEmpty).join(' · '),
      ),
      trailing: CredStatusChip.active(isActive: item.isActive, compact: true),
    );
  }
}
