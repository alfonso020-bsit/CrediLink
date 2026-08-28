import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/cred_theme.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/settings/profile_settings_sheet.dart';
import '../../shared/widgets/settings/store_settings_sheet.dart';
import '../../shared/widgets/layout/cred_sheet_scaffold.dart';

class RoleTabConfig {
  const RoleTabConfig({
    required this.role,
    required this.tabs,
    required this.screens,
  });

  final UserRole role;
  final List<NavigationDestination> tabs;
  final List<Widget> screens;
}

class RoleTabShell extends ConsumerWidget {
  const RoleTabShell({
    super.key,
    required this.config,
    required this.currentIndex,
  });

  final RoleTabConfig config;
  final int currentIndex;

  bool get _showStoreInfo =>
      config.role == UserRole.employee || config.role == UserRole.storeOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = currentIndex.clamp(0, config.screens.length - 1);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.tabs[tabIndex].label),
        actions: [
          if (config.role == UserRole.storeOwner)
            IconButton(
              tooltip: 'Store settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                final profile = profileAsync.value;
                if (profile != null) StoreSettingsSheet.show(context, profile);
              },
            ),
          if (_showStoreInfo)
            IconButton(
              tooltip: 'Store info',
              icon: const Icon(Icons.store_outlined),
              onPressed: () => _showStoreInfoSheet(context, profileAsync.value),
            ),
          if (config.role == UserRole.employee || config.role == UserRole.customer)
            IconButton(
              tooltip: 'Profile settings',
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                final profile = profileAsync.value;
                if (profile != null) ProfileSettingsSheet.show(context, profile);
              },
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: config.screens[tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) {
          context.go('${config.role.routePrefix}/tab${i + 1}');
        },
        destinations: config.tabs,
      ),
    );
  }

  void _showStoreInfoSheet(BuildContext context, UserProfile? profile) {
    if (profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CredSheetScaffold(
        title: 'Store Information',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.storeName != null && profile.storeName!.isNotEmpty)
              _InfoRow(label: 'Store', value: profile.storeName!),
            _InfoRow(label: 'Owner', value: profile.fullName),
            _InfoRow(
              label: 'Location',
              value: '${profile.barangay}, ${profile.municipality}, ${profile.province}',
            ),
            if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty)
              _InfoRow(label: 'Phone', value: profile.phoneNumber!),
            if (profile.email != null && profile.email!.isNotEmpty)
              _InfoRow(label: 'Email', value: profile.email!),
          ],
        ),
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
