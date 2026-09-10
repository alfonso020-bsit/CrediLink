import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/store_scope.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../common/cred_avatar.dart';
import '../layout/cred_modal.dart';
import '../layout/cred_sheet_scaffold.dart';

class StoreInfoSheet extends ConsumerWidget {
  const StoreInfoSheet({super.key, required this.profile});

  final UserProfile profile;

  static Future<void> show(BuildContext context, UserProfile profile) {
    return showCredModal(
      context: context,
      builder: (_) => StoreInfoSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeOwnerId = resolveStoreOwnerId(profile);
    final store = ref.watch(storeProfileProvider(storeOwnerId)).value;
    final info = ref.watch(receiptStoreInfoProvider(storeOwnerId)).value;
    final owner = profile.id == storeOwnerId
        ? profile
        : ref.watch(userProfileByIdProvider(storeOwnerId)).value;

    final name = info?.name ?? profile.storeName ?? 'Store';
    final logo = store?.storeImage ?? info?.logoUrl;
    final address = (store?.storeAddress != null && store!.storeAddress!.trim().isNotEmpty)
        ? store.storeAddress!.trim()
        : owner == null
            ? null
            : [owner.barangay, owner.municipality, owner.province]
                .where((p) => p.trim().isNotEmpty)
                .join(', ');

    return CredSheetScaffold(
      title: 'Store Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: CredAvatar(name: name, imageUrl: logo, radius: 40)),
          const SizedBox(height: CredTheme.spaceSm),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (store?.description != null && store!.description!.trim().isNotEmpty) ...[
            const SizedBox(height: CredTheme.spaceXs),
            Text(
              store.description!,
              textAlign: TextAlign.center,
              style: CredTheme.bodyMutedStyle(context),
            ),
          ],
          const SizedBox(height: CredTheme.spaceLg),
          if (owner != null) _InfoRow(label: 'Owner', value: owner.fullName),
          if (address != null && address.isNotEmpty) _InfoRow(label: 'Address', value: address),
          if (store?.businessHours != null && store!.businessHours!.trim().isNotEmpty)
            _InfoRow(label: 'Hours', value: store.businessHours!),
          if (owner?.phoneNumber != null && owner!.phoneNumber!.trim().isNotEmpty)
            _InfoRow(label: 'Phone', value: owner.phoneNumber!),
          if (owner?.email != null && owner!.email!.trim().isNotEmpty)
            _InfoRow(label: 'Email', value: owner.email!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CredTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: CredTheme.bodyMutedStyle(context)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
