import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/cred_theme.dart';
import '../../models/user_profile.dart';
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

enum _ShellMenuAction { storeSettings, storeInfo, profileSettings, logout }

class RoleTabShell extends ConsumerWidget {
  const RoleTabShell({
    super.key,
    required this.config,
    required this.currentIndex,
  });

  final RoleTabConfig config;
  final int currentIndex;

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    _ShellMenuAction action,
    UserProfile? profile,
  ) async {
    switch (action) {
      case _ShellMenuAction.storeSettings:
        if (profile != null) StoreSettingsSheet.show(context, profile);
        break;
      case _ShellMenuAction.storeInfo:
        if (profile != null) StoreInfoSheet.show(context, profile);
        break;
      case _ShellMenuAction.profileSettings:
        if (profile != null) ProfileSettingsSheet.show(context, profile);
        break;
      case _ShellMenuAction.logout:
        await ref.read(authRepositoryProvider).signOut();
        ref.invalidate(currentProfileProvider);
        if (context.mounted) context.go('/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = currentIndex.clamp(0, config.screens.length - 1);
    final profile = ref.watch(currentProfileProvider).value;
    final role = config.role;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(config.tabs[tabIndex].label),
        actions: [
          PopupMenuButton<_ShellMenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _onMenuSelected(context, ref, action, profile),
            itemBuilder: (context) => [
              if (role == UserRole.storeOwner)
                const PopupMenuItem(
                  value: _ShellMenuAction.storeSettings,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Store settings'),
                  ),
                ),
              if (role == UserRole.employee || role == UserRole.storeOwner)
                const PopupMenuItem(
                  value: _ShellMenuAction.storeInfo,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.store_outlined),
                    title: Text('Store info'),
                  ),
                ),
              if (role == UserRole.employee || role == UserRole.customer)
                const PopupMenuItem(
                  value: _ShellMenuAction.profileSettings,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_outline),
                    title: Text('Profile settings'),
                  ),
                ),
              const PopupMenuItem(
                value: _ShellMenuAction.logout,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: CredTheme.border),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey<int>(tabIndex),
                child: config.screens[tabIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: CredTheme.cardBackground,
          border: Border(top: BorderSide(color: CredTheme.border)),
        ),
        child: NavigationBar(
          selectedIndex: tabIndex,
          onDestinationSelected: (i) {
            context.go('${config.role.routePrefix}/tab${i + 1}');
          },
          destinations: config.tabs,
        ),
      ),
    );
  }
}
