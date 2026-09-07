import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/store_profile.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
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
    final profile = ref.watch(currentProfileProvider).value;
    final storesAsync = ref.watch(allStoresProvider);

    return CredAsyncView<List<StoreProfile>>(
      asyncValue: storesAsync,
      emptyMessage: 'No stores in your area',
      onRetry: () => ref.invalidate(allStoresProvider),
      builder: (allStores) {
        final areaStores = _filterByLocation(allStores, profile);
        final stores = _filterStores(areaStores);

        return CredTabPageLayout(
          onRefresh: () async {
            ref.invalidate(allStoresProvider);
            await ref.read(allStoresProvider.future);
          },
          children: [
            CredSection(
              title: 'Stores near you',
              subtitle:
                  '${areaStores.length} store${areaStores.length == 1 ? '' : 's'} accepting CrediLink'
                  '${profile != null && profile.province.isNotEmpty ? ' in your area' : ''}',
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search stores...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            if (stores.isEmpty)
              EmptyState(
                title: areaStores.isEmpty ? 'No stores' : 'No matches',
                message: areaStores.isEmpty
                    ? 'No stores found in ${profile?.municipality ?? 'your area'}'
                    : 'No stores match your search',
              )
            else
              for (var i = 0; i < stores.length; i++) ...[
                if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                CredSurfaceTile(
                  leading: CredAvatar(
                    name: stores[i].displayName,
                    imageUrl: stores[i].storeImage,
                  ),
                  title: Text(
                    stores[i].displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    CustomerHelpers.storeLocation(stores[i]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: CredTheme.subtitleText),
                  onTap: () => _openStore(context, ref, stores[i]),
                ),
              ],
          ],
        );
      },
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
      return store.displayName.toLowerCase().contains(q) ||
          (store.ownerName?.toLowerCase().contains(q) ?? false) ||
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
