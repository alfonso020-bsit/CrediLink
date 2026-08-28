import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/cred_snackbar.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _UserDetailSheet(
        user: user,
        onToggleStatus: (active) async {
          await _toggleStatus(user, active);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: _roles
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(right: 8),
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
        Expanded(
          child: FutureBuilder<List<UserProfile>>(
            future: _usersFuture,
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
              final users = _filterUsers(snap.data ?? []);
              if (users.isEmpty) {
                return const EmptyState(message: 'No users found');
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    return ListTile(
                      leading: CredAvatar(name: u.fullName),
                      title: Text(u.fullName),
                      subtitle: Text('${u.role.displayName} • ${u.status}'),
                      trailing: Switch(
                        value: u.isActive,
                        onChanged: (v) => _toggleStatus(u, v),
                      ),
                      onTap: () => _showUserDetail(u),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({
    required this.user,
    required this.onToggleStatus,
  });

  final UserProfile user;
  final Future<void> Function(bool active) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              CredAvatar(name: user.fullName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                    Text(user.role.displayName, style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active account'),
            value: user.isActive,
            onChanged: (v) => onToggleStatus(v),
          ),
        ],
      ),
    );
  }
}
