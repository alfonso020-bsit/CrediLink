import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_modal.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../widgets/admin_console_table.dart';
import '../widgets/admin_detail_row.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _filter = 'All';
  late Future<List<UserProfile>> _usersFuture;

  static const _roles = ['All', 'Admin', 'StoreOwner', 'Employee', 'Customer'];

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<UserProfile>> _loadUsers() =>
      ref.read(adminRepositoryProvider).getAllUsers();

  Future<void> _refresh() async {
    setState(() => _usersFuture = _loadUsers());
    await _usersFuture;
  }

  List<UserProfile> _filterUsers(List<UserProfile> users) {
    if (_filter == 'All') return users;
    return users.where((u) => u.role.value == _filter).toList();
  }

  Future<void> _toggleStatus(UserProfile user, bool active) async {
    await ref.read(authRepositoryProvider).updateUserStatus(
          user.id,
          active ? 'active' : 'inactive',
        );
    if (!mounted) return;
    CredSnackBar.show(context, 'Status updated');
    await _refresh();
  }

  void _showUserDetail(UserProfile user) {
    showCredModal(
      context: context,
      builder: (sheetContext) => CredSheetScaffold(
        title: user.fullName,
        child: _UserDetailBody(
          user: user,
          onToggleStatus: (active) async {
            await _toggleStatus(user, active);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _usersFuture,
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
        final allUsers = snap.data ?? [];
        final users = _filterUsers(allUsers);
        final activeCount = allUsers.where((u) => u.isActive).length;

        return CredTabPageLayout(
          onRefresh: _refresh,
          children: [
            const SizedBox(height: CredTheme.spaceMd),
            CredSection(
              title: 'Users',
              subtitle: '$activeCount active of ${allUsers.length}',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roles
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(right: CredTheme.spaceXs),
                          child: FilterChip(
                            label: Text(r == 'StoreOwner' ? 'Store Owner' : r),
                            selected: _filter == r,
                            onSelected: (_) => setState(() => _filter = r),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Directory',
              subtitle: '${users.length} shown',
              child: users.isEmpty
                  ? const EmptyState(message: 'No users found')
                  : AdminConsoleTable.isConsoleLayout
                      ? AdminConsoleTable(
                          columns: const ['Name', 'Role', 'Email', 'Status'],
                          rows: [
                            for (final user in users)
                              AdminConsoleTableRow(
                                onTap: () => _showUserDetail(user),
                                cells: [
                                  Text(
                                    user.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(user.role.displayName),
                                  Text(
                                    user.email ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CredStatusChip.active(
                                          isActive: user.isActive,
                                          compact: true,
                                        ),
                                        Switch(
                                          value: user.isActive,
                                          onChanged: (v) => _toggleStatus(user, v),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < users.length; i++) ...[
                              if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                              _UserTile(
                                user: users[i],
                                onTap: () => _showUserDetail(users[i]),
                                onToggle: (v) => _toggleStatus(users[i], v),
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

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    required this.onToggle,
  });

  final UserProfile user;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return CredSurfaceTile(
      onTap: onTap,
      leading: CredAvatar(name: user.fullName, imageUrl: user.profileImage),
      title: Text(user.fullName),
      subtitle: Text(user.role.displayName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CredStatusChip.active(isActive: user.isActive, compact: true),
          const SizedBox(width: CredTheme.spaceXs),
          Switch(
            value: user.isActive,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  const _UserDetailBody({
    required this.user,
    required this.onToggleStatus,
  });

  final UserProfile user;
  final Future<void> Function(bool active) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CredAvatar(name: user.fullName, size: 48, imageUrl: user.profileImage),
            const SizedBox(width: CredTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: CredTheme.pageTitle(context)),
                  Text(user.role.displayName, style: CredTheme.bodyMutedStyle(context)),
                ],
              ),
            ),
            CredStatusChip.active(isActive: user.isActive),
          ],
        ),
        const SizedBox(height: CredTheme.spaceMd),
        AdminDetailRow(label: 'Username', value: user.username),
        AdminDetailRow(label: 'Email', value: user.email ?? 'N/A'),
        AdminDetailRow(label: 'Phone', value: user.phoneNumber ?? 'N/A'),
        AdminDetailRow(label: 'Status', value: user.status),
        AdminDetailRow(
          label: 'Address',
          value: [user.barangay, user.municipality, user.province]
              .where((e) => e.isNotEmpty)
              .join(', '),
        ),
        if (user.storeName != null) AdminDetailRow(label: 'Store', value: user.storeName!),
        if (user.position != null) AdminDetailRow(label: 'Position', value: user.position!),
        if (user.createdAt != null)
          AdminDetailRow(label: 'Joined', value: DateFormat.yMMMd().format(user.createdAt!)),
        const SizedBox(height: CredTheme.spaceSm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active account'),
          value: user.isActive,
          onChanged: (v) => onToggleStatus(v),
        ),
      ],
    );
  }
}
