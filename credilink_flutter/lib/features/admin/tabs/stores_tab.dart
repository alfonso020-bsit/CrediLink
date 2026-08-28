import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/cred_snackbar.dart';
import '../../../models/store_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/filters/cred_segmented_filter.dart';
import '../widgets/admin_detail_row.dart';

class _StoreListItem {
  const _StoreListItem({
    required this.store,
    required this.ownerStatus,
    required this.ownerName,
  });

  final StoreProfile store;
  final String ownerStatus;
  final String ownerName;

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
        return s.store.storeName.toLowerCase().contains(q) ||
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
        content: Text('Are you sure you want to $action ${item.store.storeName}?'),
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

  void _showStoreDetail(_StoreListItem item) {
    final store = item.store;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(store.storeName, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminDetailRow(label: 'Owner', value: item.ownerName),
            AdminDetailRow(label: 'Status', value: item.ownerStatus),
            AdminDetailRow(
              label: 'Location',
              value: [store.barangay, store.municipality, store.province]
                  .whereType<String>()
                  .where((e) => e.isNotEmpty)
                  .join(', '),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => _toggleStoreStatus(item),
                child: Text(item.isActive ? 'Deactivate Store' : 'Activate Store'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CredSearchField(
            controller: _searchController,
            hint: 'Search stores…',
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CredSegmentedFilter<String>(
            options: const ['all', 'active', 'inactive'],
            selected: _statusFilter,
            onChanged: (v) => setState(() => _statusFilter = v),
            labelBuilder: (v) => switch (v) {
              'active' => 'Active',
              'inactive' => 'Inactive',
              _ => 'All',
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<_StoreListItem>>(
            future: _storesFuture,
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
              final allItems = snap.data ?? [];
              final provinces = _provinces(allItems);
              final municipalities = _municipalities(allItems);
              final filtered = _filter(allItems);

              return Column(
                children: [
                  if (provinces.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _provinceFilter,
                              decoration: const InputDecoration(
                                labelText: 'Province',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All provinces')),
                                for (final p in provinces)
                                  DropdownMenuItem<String?>(value: p, child: Text(p)),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _municipalityFilter,
                              decoration: const InputDecoration(
                                labelText: 'Municipality',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All municipalities')),
                                for (final m in municipalities)
                                  DropdownMenuItem<String?>(value: m, child: Text(m)),
                              ],
                              onChanged: (v) => setState(() => _municipalityFilter = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const EmptyState(message: 'No stores found')
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                final location = [item.store.municipality, item.store.province]
                                    .whereType<String>()
                                    .where((e) => e.isNotEmpty)
                                    .join(', ');
                                return ListTile(
                                  leading: Icon(
                                    Icons.storefront,
                                    color: item.isActive ? Colors.green : Colors.grey,
                                  ),
                                  title: Text(item.store.storeName),
                                  subtitle: Text(
                                    [item.ownerName, location].where((e) => e.isNotEmpty).join(' • '),
                                  ),
                                  trailing: Switch(
                                    value: item.isActive,
                                    onChanged: (_) => _toggleStoreStatus(item),
                                  ),
                                  onTap: () => _showStoreDetail(item),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
