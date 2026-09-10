import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/masquerade/masquerade_provider.dart';
import '../../core/theme/cred_theme.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';
import '../shared/role_tab_shell.dart';

/// Full-bleed desktop console for Admin (and Admin masquerade as Store Owner) on Flutter Web.
class AdminConsoleShell extends ConsumerWidget {
  const AdminConsoleShell({
    super.key,
    required this.config,
    required this.currentIndex,
  });

  final RoleTabConfig config;
  final int currentIndex;

  static const double _sidebarWidth = 248;
  static const double _contentMaxWidth = 1280;

  void _goTab(BuildContext context, int index) {
    context.go('${config.role.routePrefix}/tab${index + 1}');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    clearMasquerade(ref);
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(currentProfileProvider);
    if (context.mounted) context.go('/login');
  }

  void _exitMasquerade(BuildContext context, WidgetRef ref) {
    clearMasquerade(ref);
    context.go('/admin/tab2');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = currentIndex.clamp(0, config.screens.length - 1);
    final masquerade = ref.watch(masqueradeProvider);
    final isMasquerading =
        masquerade != null && config.role == UserRole.storeOwner;
    final profile = isMasquerading
        ? masquerade.ownerProfile
        : ref.watch(currentProfileProvider).value;
    final pageLabel = config.tabs[tabIndex].label;
    final sidebarTitle = isMasquerading ? 'Store view' : 'Admin console';
    final userName = isMasquerading
        ? (masquerade.storeName.isNotEmpty
            ? masquerade.storeName
            : profile?.fullName ?? 'Store')
        : (profile?.fullName ?? 'Admin');
    final userEmail = isMasquerading ? profile?.email : profile?.email;

    return Scaffold(
      backgroundColor: CredTheme.scaffoldBackground,
      body: Row(
        children: [
          _Sidebar(
            width: _sidebarWidth,
            selectedIndex: tabIndex,
            tabs: config.tabs,
            consoleSubtitle: sidebarTitle,
            userName: userName,
            userEmail: userEmail,
            isMasquerading: isMasquerading,
            onSelect: (i) => _goTab(context, i),
            onLogout: () => _logout(context, ref),
            onExitMasquerade: () => _exitMasquerade(context, ref),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(title: pageLabel),
                if (isMasquerading)
                  Material(
                    color: CredTheme.warning.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            color: CredTheme.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Viewing as ${masquerade.storeName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CredTheme.titleText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _exitMasquerade(context, ref),
                            child: const Text('Exit'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ColoredBox(
                    color: CredTheme.scaffoldBackground,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth >= _contentMaxWidth
                            ? _contentMaxWidth
                            : constraints.maxWidth;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            height: constraints.maxHeight,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: KeyedSubtree(
                                key: ValueKey<int>(tabIndex),
                                child: config.screens[tabIndex],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CredTheme.cardBackground,
      child: Container(
        height: 64,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceLg),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CredTheme.border)),
        ),
        child: Text(
          title,
          style: CredTheme.pageTitle(context).copyWith(fontSize: 20),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.selectedIndex,
    required this.tabs,
    required this.consoleSubtitle,
    required this.userName,
    required this.onSelect,
    required this.onLogout,
    required this.onExitMasquerade,
    required this.isMasquerading,
    this.userEmail,
  });

  final double width;
  final int selectedIndex;
  final List<NavigationDestination> tabs;
  final String consoleSubtitle;
  final String userName;
  final String? userEmail;
  final bool isMasquerading;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onExitMasquerade;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CredTheme.cardBackground,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: CredTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CredTheme.inputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CredTheme.border),
                      ),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: CredTheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CrediLink',
                            style: CredTheme.sectionTitle(context).copyWith(fontSize: 15),
                          ),
                          Text(
                            consoleSubtitle,
                            style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: CredTheme.border),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = index == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: selected
                            ? CredTheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                IconTheme(
                                  data: IconThemeData(
                                    size: 22,
                                    color: selected ? CredTheme.primary : CredTheme.subtitleText,
                                  ),
                                  child: selected
                                      ? (tab.selectedIcon ?? tab.icon)
                                      : tab.icon,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tab.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? CredTheme.primary : CredTheme.titleText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: CredTheme.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CredTheme.titleText,
                      ),
                    ),
                    if (userEmail != null && userEmail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isMasquerading)
                      OutlinedButton.icon(
                        onPressed: onExitMasquerade,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Exit masquerade'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
