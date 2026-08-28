import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/store_profile.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../customer_helpers.dart';
import 'store_detail_sheet.dart';

class CustomerProductsTab extends ConsumerStatefulWidget {
  const CustomerProductsTab({super.key});

  @override
  ConsumerState<CustomerProductsTab> createState() => _CustomerProductsTabState();
}

class _CustomerProductsTabState extends ConsumerState<CustomerProductsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        return FutureBuilder<List<StoreProfile>>(
          future: ref.read(storeRepositoryProvider).getAllStores(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final allStores = snap.data!;
            final areaStores = _filterByLocation(allStores, profile);
            final stores = _filterStores(areaStores);

            if (allStores.isEmpty) {
              return const EmptyState(message: 'No stores in your area');
            }

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: CredTheme.pagePadding,
                children: [
                  Text(
                    '${areaStores.length} store${areaStores.length == 1 ? '' : 's'} accepting CrediLink'
                    '${profile != null && profile.province.isNotEmpty ? ' in your area' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search stores...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                  const SizedBox(height: CredTheme.spaceMd),
                  if (stores.isEmpty)
                    EmptyState(
                      message: areaStores.isEmpty
                          ? 'No stores found in ${profile?.municipality ?? 'your area'}'
                          : 'No stores match your search',
                    )
                  else
                    ...stores.map(
                      (store) => Card(
                        margin: const EdgeInsets.only(bottom: CredTheme.spaceXs),
                        child: ListTile(
                          leading: CredAvatar(name: store.storeName),
                          title: Text(store.storeName),
                          subtitle: Text(CustomerHelpers.storeLocation(store)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openStore(context, ref, store),
                        ),
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

  List<StoreProfile> _filterByLocation(List<StoreProfile> stores, UserProfile? profile) {
    if (profile == null || profile.province.isEmpty) return stores;

    var filtered = stores.where((store) {
      final storeProvince = store.province?.trim().toLowerCase();
      if (storeProvince == null || storeProvince.isEmpty) return true;
      return storeProvince == profile.province.trim().toLowerCase();
    }).toList();

    if (profile.municipality.isNotEmpty) {
      filtered = filtered.where((store) {
        final storeMunicipality = store.municipality?.trim().toLowerCase();
        if (storeMunicipality == null || storeMunicipality.isEmpty) return true;
        return storeMunicipality == profile.municipality.trim().toLowerCase();
      }).toList();
    }

    return filtered;
  }

  List<StoreProfile> _filterStores(List<StoreProfile> stores) {
    if (_query.isEmpty) return stores;
    final q = _query.toLowerCase();
    return stores.where((store) {
      return store.storeName.toLowerCase().contains(q) ||
          CustomerHelpers.storeLocation(store).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openStore(BuildContext context, WidgetRef ref, StoreProfile store) async {
    final products = await ref
        .read(productRepositoryProvider)
        .getProductsByStore(store.storeOwnerId);
    if (!context.mounted) return;
    await StoreDetailSheet.show(context, store: store, products: products);
  }
}
