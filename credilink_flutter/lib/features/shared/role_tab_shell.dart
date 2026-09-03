import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/settings/profile_settings_sheet.dart';
import '../../shared/widgets/settings/store_info_sheet.dart';
import '../../shared/widgets/settings/store_settings_sheet.dart';

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
              onPressed: () {
                final profile = profileAsync.value;
                if (profile != null) StoreInfoSheet.show(context, profile);
              },
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
              ref.invalidate(currentProfileProvider);
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
}
