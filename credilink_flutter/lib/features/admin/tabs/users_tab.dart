import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/masquerade/masquerade_provider.dart';
import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
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

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _filter = 'All';
  String _statusFilter = 'all';
  String _search = '';
  final _searchController = TextEditingController();
  late Future<List<UserProfile>> _usersFuture;

  static const _roles = ['All', 'Admin', 'StoreOwner', 'Employee', 'Customer'];

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<UserProfile>> _loadUsers() =>
      ref.read(adminRepositoryProvider).getAllUsers();

  Future<void> _refresh() async {
    setState(() => _usersFuture = _loadUsers());
    await _usersFuture;
  }

  List<UserProfile> _filterUsers(List<UserProfile> users) {
    var result = users;
    if (_filter != 'All') {
      result = result.where((u) => u.role.value == _filter).toList();
    }
    if (_statusFilter == 'active') {
      result = result.where((u) => u.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      result = result.where((u) => !u.isActive).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            (u.email ?? '').toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  bool _hasDeliverableEmail(UserProfile user) {
    final email = user.email?.trim().toLowerCase() ?? '';
    if (!email.contains('@')) return false;
    return !email.endsWith('@employees.credilink.local') &&
        !email.endsWith('@customers.credilink.local');
  }

  Future<void> _recordStatusChange({
    required String targetId,
    required String targetName,
    required String targetKind,
    required String oldStatus,
    required String newStatus,
  }) async {
    final actor = ref.read(currentProfileProvider).value;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    await ref.read(adminRepositoryProvider).recordStatusChange(
          actorId: actor?.id ?? uid,
          actorName: actor?.fullName ?? 'Admin',
          targetId: targetId,
          targetName: targetName,
          targetKind: targetKind,
          oldStatus: oldStatus,
          newStatus: newStatus,
        );
    ref.invalidate(adminAuditLogProvider);
  }

  bool _isSignedInUser(UserProfile user) {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final profileId = ref.read(currentProfileProvider).value?.id;
    return (uid != null && user.id == uid) || (profileId != null && user.id == profileId);
  }

  bool _canViewAs(UserProfile user) =>
      user.role == UserRole.storeOwner && user.isActive;

  Future<void> _toggleStatus(UserProfile user) async {
    if (_isSignedInUser(user)) {
      CredSnackBar.show(context, 'You cannot change your own status', isError: true);
      return;
    }

    final activating = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activating ? 'Activate account?' : 'Deactivate account?'),
        content: Text(
          activating
              ? '${user.fullName} will be able to sign in again.'
              : '${user.fullName} will not be able to sign in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(authRepositoryProvider).updateUserStatus(
            user.id,
            activating ? 'active' : 'inactive',
          );
      if (!mounted) return;
      var logged = true;
      try {
        await _recordStatusChange(
          targetId: user.id,
          targetName: user.fullName,
          targetKind: 'user',
          oldStatus: user.status,
          newStatus: activating ? 'active' : 'inactive',
        );
      } catch (_) {
        logged = false;
      }
      if (!mounted) return;
      ref.invalidate(adminPlatformSnapshotProvider);
      CredSnackBar.show(context, activating ? 'Account activated' : 'Account deactivated');
      if (!logged) {
        CredSnackBar.show(
          context,
          'The status changed, but it was not added to the activity log.',
          isError: true,
        );
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      CredSnackBar.error(context, e, fallback: "Couldn't update this account.");
    }
  }

  Future<void> _startMasquerade(UserProfile user) async {
    if (!_canViewAs(user)) {
      CredSnackBar.show(context, 'Only an active store owner can be viewed', isError: true);
      return;
    }

    final storeName = (user.storeName?.trim().isNotEmpty ?? false)
        ? user.storeName!.trim()
        : user.fullName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('View as store owner?'),
        content: Text(
          'You will view $storeName as ${user.fullName}. '
          'You stay signed in as Admin. Exit anytime to return to the console.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.read(masqueradeProvider.notifier).start(MasqueradeSession(
          storeOwnerId: user.id,
          storeName: storeName,
          ownerProfile: user,
        ));
    if (!mounted) return;
    context.go('/storeowner/tab1');
  }

  Future<void> _sendPasswordReset(UserProfile user) async {
    final email = user.email?.trim() ?? '';
    if (!_hasDeliverableEmail(user)) {
      CredSnackBar.show(
        context,
        'This account has no email that can receive a reset link.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send password reset?'),
        content: Text('A reset link will be emailed to $email. You stay signed in as Admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      CredSnackBar.show(context, 'Password reset email sent');
    } catch (e) {
      if (!mounted) return;
      CredSnackBar.error(context, e, fallback: "Couldn't send the reset email.");
    }
  }

  void _showUserDetail(UserProfile user) {
    final isSelf = _isSignedInUser(user);
    showCredModal(
      context: context,
      builder: (sheetContext) => CredSheetScaffold(
        title: user.fullName,
        child: _UserDetailBody(
          user: user,
          canViewAs: _canViewAs(user),
          canChangeStatus: !isSelf,
          canResetPassword: _hasDeliverableEmail(user),
          onViewAs: () {
            Navigator.pop(sheetContext);
            _startMasquerade(user);
          },
          onToggleStatus: () {
            Navigator.pop(sheetContext);
            _toggleStatus(user);
          },
          onResetPassword: () {
            Navigator.pop(sheetContext);
            _sendPasswordReset(user);
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
            title: 'Could not load users',
            message: 'Something went wrong. Try again.',
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
              title: '$activeCount active of ${allUsers.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CredSearchField(
                    controller: _searchController,
                    hint: 'Search name, email, or username…',
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
                  const SizedBox(height: CredTheme.spaceSm),
                  CredSegmentedFilter<String>(
                    options: _roles,
                    selected: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                    labelBuilder: (r) => r == 'StoreOwner' ? 'Store Owner' : r,
                  ),
                ],
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
                          columns: const [
                            AdminConsoleColumn('Name', flex: 4),
                            AdminConsoleColumn('Role', flex: 3),
                            AdminConsoleColumn('Email', flex: 5),
                            AdminConsoleColumn('Status', width: 108),
                            AdminConsoleColumn('Actions', width: 152),
                          ],
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
                                    child: CredStatusChip.active(
                                      isActive: user.isActive,
                                      compact: true,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _UserActionIcons(
                                      canViewAs: _canViewAs(user),
                                      isActive: user.isActive,
                                      canChangeStatus: !_isSignedInUser(user),
                                      canResetPassword: _hasDeliverableEmail(user),
                                      onViewAs: () => _startMasquerade(user),
                                      onToggleStatus: () => _toggleStatus(user),
                                      onResetPassword: () => _sendPasswordReset(user),
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
                                canViewAs: _canViewAs(users[i]),
                                canChangeStatus: !_isSignedInUser(users[i]),
                                canResetPassword: _hasDeliverableEmail(users[i]),
                                onViewAs: () => _startMasquerade(users[i]),
                                onToggleStatus: () => _toggleStatus(users[i]),
                                onResetPassword: () => _sendPasswordReset(users[i]),
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

class _UserActionIcons extends StatelessWidget {
  const _UserActionIcons({
    required this.canViewAs,
    required this.isActive,
    required this.canChangeStatus,
    required this.canResetPassword,
    required this.onViewAs,
    required this.onToggleStatus,
    required this.onResetPassword,
  });

  final bool canViewAs;
  final bool isActive;
  final bool canChangeStatus;
  final bool canResetPassword;
  final VoidCallback onViewAs;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canViewAs)
          IconButton(
            tooltip: 'View as store owner',
            onPressed: onViewAs,
            icon: const Icon(Icons.face_retouching_natural, size: 20),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        if (canResetPassword)
          IconButton(
            tooltip: 'Send password reset',
            onPressed: onResetPassword,
            icon: const Icon(Icons.lock_reset, size: 20),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        if (canChangeStatus)
          IconButton(
            tooltip: isActive ? 'Deactivate' : 'Activate',
            onPressed: onToggleStatus,
            icon: Icon(
              isActive ? Icons.block_outlined : Icons.check_circle_outline,
              size: 20,
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    required this.canViewAs,
    required this.canChangeStatus,
    required this.canResetPassword,
    required this.onViewAs,
    required this.onToggleStatus,
    required this.onResetPassword,
  });

  final UserProfile user;
  final VoidCallback onTap;
  final bool canViewAs;
  final bool canChangeStatus;
  final bool canResetPassword;
  final VoidCallback onViewAs;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;

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
          _UserActionIcons(
            canViewAs: canViewAs,
            isActive: user.isActive,
            canChangeStatus: canChangeStatus,
            canResetPassword: canResetPassword,
            onViewAs: onViewAs,
            onToggleStatus: onToggleStatus,
            onResetPassword: onResetPassword,
          ),
        ],
      ),
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  const _UserDetailBody({
    required this.user,
    required this.canViewAs,
    required this.canChangeStatus,
    required this.canResetPassword,
    required this.onViewAs,
    required this.onToggleStatus,
    required this.onResetPassword,
  });

  final UserProfile user;
  final bool canViewAs;
  final bool canChangeStatus;
  final bool canResetPassword;
  final VoidCallback onViewAs;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;

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
        const SizedBox(height: CredTheme.spaceMd),
        if (canViewAs) ...[
          FilledButton.icon(
            onPressed: onViewAs,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('View as store owner'),
          ),
          const SizedBox(height: CredTheme.spaceSm),
        ],
        if (canResetPassword) ...[
          OutlinedButton.icon(
            onPressed: onResetPassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Send password reset'),
          ),
          const SizedBox(height: CredTheme.spaceSm),
        ],
        if (canChangeStatus)
          FilledButton.tonal(
            onPressed: onToggleStatus,
            child: Text(user.isActive ? 'Deactivate account' : 'Activate account'),
          ),
      ],
    );
  }
}
