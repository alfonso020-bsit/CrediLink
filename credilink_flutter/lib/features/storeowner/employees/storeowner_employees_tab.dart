import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/cred_snackbar.dart';
import '../../../core/utils/cred_validators.dart';
import '../../../models/ph_address.dart';
import '../../../models/sale_record.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/repositories.dart';
import '../../../services/employee_report_pdf_service.dart';
import '../../../shared/widgets/address/ph_address_picker.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/cred_avatar.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/filters/cred_search_field.dart';
import '../../../shared/widgets/forms/cred_form_field.dart';
import '../../../shared/widgets/layout/cred_metric_card.dart';
import '../../../shared/widgets/layout/cred_quick_action_grid.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_sheet_scaffold.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/settings/profile_settings_sheet.dart';

class StoreOwnerEmployeesTab extends ConsumerStatefulWidget {
  const StoreOwnerEmployeesTab({super.key});

  @override
  ConsumerState<StoreOwnerEmployeesTab> createState() => _StoreOwnerEmployeesTabState();
}

class _StoreOwnerEmployeesTabState extends ConsumerState<StoreOwnerEmployeesTab> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'No profile',
      builder: (p) {
        if (p == null) return const EmptyState(message: 'No profile');
        final employees = ref.watch(storeEmployeesProvider(p.id));

        return CredAsyncView<List<UserProfile>>(
          asyncValue: employees,
          builder: (items) {
            final filtered = _filterEmployees(items);
            final active = items.where((e) => e.isActive).length;

            return CredTabPageLayout(
              onRefresh: () async {
                ref.invalidate(storeEmployeesProvider(p.id));
                await ref.read(storeEmployeesProvider(p.id).future);
              },
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showCreateEmployeeSheet(context, p.id),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Employee'),
              ),
              children: [
                const SizedBox(height: CredTheme.spaceMd),
                CredSection(
                  title: 'Team',
                  subtitle: '$active active of ${items.length}',
                  child: CredMetricGrid(
                    metrics: [
                      CredMetricCard(
                        label: 'Total',
                        value: '${items.length}',
                        icon: Icons.groups,
                        accentColor: CredTheme.info,
                      ),
                      CredMetricCard(
                        label: 'Active',
                        value: '$active',
                        icon: Icons.badge,
                        accentColor: CredTheme.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CredTheme.spaceLg),
                CredSection(
                  title: 'Directory',
                  child: Column(
                    children: [
                      CredSearchField(
                        controller: _searchController,
                        hint: 'Search employees',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: CredTheme.spaceXs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['all', 'active', 'inactive']
                              .map(
                                (status) => Padding(
                                  padding: const EdgeInsets.only(right: CredTheme.spaceXs),
                                  child: FilterChip(
                                    label: Text(
                                      status[0].toUpperCase() + status.substring(1),
                                    ),
                                    selected: _statusFilter == status,
                                    onSelected: (_) => setState(() => _statusFilter = status),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: CredTheme.spaceMd),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
                          child: EmptyState(message: 'No employees found'),
                        )
                      else
                        for (var i = 0; i < filtered.length; i++) ...[
                          if (i > 0) const SizedBox(height: CredTheme.spaceXs),
                          _EmployeeTile(
                            employee: filtered[i],
                            onTap: () => _showEmployeeDetail(context, filtered[i], p.id),
                          ),
                        ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<UserProfile> _filterEmployees(List<UserProfile> employees) {
    var filtered = employees;
    final term = _searchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      filtered = filtered
          .where(
            (e) =>
                e.fullName.toLowerCase().contains(term) ||
                e.username.toLowerCase().contains(term) ||
                (e.position ?? '').toLowerCase().contains(term),
          )
          .toList();
    }
    if (_statusFilter == 'active') {
      filtered = filtered.where((e) => e.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      filtered = filtered.where((e) => !e.isActive).toList();
    }
    return filtered;
  }

  void _showEmployeeDetail(BuildContext context, UserProfile employee, String storeOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: employee.fullName,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CredAvatar(name: employee.fullName, size: 56),
                const SizedBox(width: CredTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.position ?? 'Employee',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      CredStatusChip.active(isActive: employee.isActive),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CredTheme.spaceMd),
            _DetailLine(label: 'Username', value: employee.username),
            _DetailLine(label: 'Email', value: employee.email ?? '—'),
            _DetailLine(label: 'Phone', value: employee.phoneNumber ?? '—'),
            _DetailLine(
              label: 'Address',
              value: '${employee.barangay}, ${employee.municipality}, ${employee.province}',
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Actions',
              child: CredQuickActionGrid(
                actions: [
                  CredQuickAction(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditEmployee(context, employee, storeOwnerId);
                    },
                  ),
                  CredQuickAction(
                    label: 'Salary',
                    icon: Icons.payments_outlined,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSalarySheet(context, employee);
                    },
                  ),
                  CredQuickAction(
                    label: 'Analytics',
                    icon: Icons.analytics_outlined,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAnalytics(context, employee, storeOwnerId);
                    },
                  ),
                  CredQuickAction(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final sales = await ref.read(storeSalesProvider(storeOwnerId).future);
                      await EmployeeReportPdfService().exportEmployeeReport(
                        employee: employee,
                        sales: sales,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            if (employee.isActive)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _toggleStatus(employee, storeOwnerId, inactive: true);
                },
                icon: const Icon(Icons.person_off),
                label: const Text('Deactivate Employee'),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _toggleStatus(employee, storeOwnerId, inactive: false);
                },
                icon: const Icon(Icons.person),
                label: const Text('Activate Employee'),
              ),
            const SizedBox(height: CredTheme.spaceXs),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteEmployee(employee, storeOwnerId);
              },
              icon: const Icon(Icons.delete_outline, color: CredTheme.danger),
              label: const Text('Delete Employee', style: TextStyle(color: CredTheme.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(
    UserProfile employee,
    String storeOwnerId, {
    required bool inactive,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inactive ? 'Deactivate Employee' : 'Activate Employee'),
        content: Text(
          inactive
              ? 'Deactivate ${employee.fullName}? They will not be able to log in.'
              : 'Reactivate ${employee.fullName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final newStatus = inactive ? 'inactive' : 'active';
    await ref.read(authRepositoryProvider).updateUserStatus(employee.id, newStatus);
    ref.invalidate(storeEmployeesProvider(storeOwnerId));
    if (mounted) {
      CredSnackBar.show(context, 'Employee ${inactive ? 'deactivated' : 'activated'}');
    }
  }

  Future<void> _deleteEmployee(UserProfile employee, String storeOwnerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Permanently delete ${employee.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authRepositoryProvider).deleteEmployee(employee.id);
    ref.invalidate(storeEmployeesProvider(storeOwnerId));
    if (mounted) CredSnackBar.show(context, 'Employee deleted');
  }

  void _showEditEmployee(BuildContext context, UserProfile employee, String storeOwnerId) {
    ProfileSettingsSheet.show(context, employee).then((_) {
      ref.invalidate(storeEmployeesProvider(storeOwnerId));
    });
  }

  void _showSalarySheet(BuildContext context, UserProfile employee) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: 'Record Salary',
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: CredTheme.spaceMd),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) return;
                await ref.read(authRepositoryProvider).recordEmployeeSalary(
                      employeeId: employee.id,
                      amount: amount,
                      notes: notesController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) CredSnackBar.show(context, 'Salary recorded');
              },
              child: const Text('Save Salary Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAnalytics(BuildContext context, UserProfile employee, String storeOwnerId) async {
    final sales = await ref.read(storeSalesProvider(storeOwnerId).future);
    if (!mounted) return;
    final mine = sales.where((s) => s.employeeId == employee.id).toList();
    final revenue = mine.fold<double>(0, (sum, s) => sum + s.total);
    final cashCount = mine.where((s) => s.type == SaleType.cash).length;
    final debtCount = mine.where((s) => s.type == SaleType.debt).length;

    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      builder: (ctx) => CredSheetScaffold(
        title: '${employee.fullName} · Analytics',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredMetricCard(
              label: 'Revenue',
              value: CurrencyFormatter.format(revenue),
              icon: Icons.trending_up,
              accentColor: CredTheme.success,
              style: CredMetricStyle.featured,
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredMetricGrid(
              metrics: [
                CredMetricCard(
                  label: 'Transactions',
                  value: '${mine.length}',
                  icon: Icons.receipt_long,
                  accentColor: CredTheme.info,
                ),
                CredMetricCard(
                  label: 'Cash sales',
                  value: '$cashCount',
                  icon: Icons.payments,
                  accentColor: CredTheme.success,
                ),
                CredMetricCard(
                  label: 'Debt sales',
                  value: '$debtCount',
                  icon: Icons.receipt,
                  accentColor: CredTheme.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateEmployeeSheet(BuildContext context, String storeOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateEmployeeSheet(
        storeOwnerId: storeOwnerId,
        onCreated: () {
          ref.invalidate(storeEmployeesProvider(storeOwnerId));
          CredSnackBar.show(context, 'Employee created');
        },
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});

  final UserProfile employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CredSurfaceTile(
      onTap: onTap,
      leading: CredAvatar(name: employee.fullName),
      title: Text(employee.fullName),
      subtitle: Text('${employee.position ?? 'Employee'} · ${employee.username}'),
      trailing: CredStatusChip.active(isActive: employee.isActive, compact: true),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: CredTheme.bodyMutedStyle(context))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CreateEmployeeSheet extends ConsumerStatefulWidget {
  const _CreateEmployeeSheet({
    required this.storeOwnerId,
    required this.onCreated,
  });

  final String storeOwnerId;
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateEmployeeSheet> createState() => _CreateEmployeeSheetState();
}

class _CreateEmployeeSheetState extends ConsumerState<_CreateEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();
  final _sitio = TextEditingController();
  PhAddress? _address;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _position.dispose();
    _sitio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CredSheetScaffold(
      title: 'Create Employee',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredTextField(
              controller: _username,
              label: 'Username',
              icon: Icons.alternate_email,
              required: true,
              textInputAction: TextInputAction.next,
              validator: (v) => CredValidators.required(v, message: 'Enter a username'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredPasswordField(
              controller: _password,
              newPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(
              controller: _fullName,
              label: 'Full Name',
              icon: Icons.person_outline,
              required: true,
              textInputAction: TextInputAction.next,
              validator: (v) => CredValidators.required(v, message: 'Enter a name'),
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredTextField(
              controller: _position,
              label: 'Position',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CredTheme.spaceSm),
            CredEmailField(controller: _email, required: false),
            const SizedBox(height: CredTheme.spaceSm),
            CredPhoneField(controller: _phone),
            const SizedBox(height: CredTheme.spaceMd),
            PhAddressPicker(
              sitioController: _sitio,
              onChanged: (address) => _address = address,
            ),
            const SizedBox(height: CredTheme.spaceMd),
            CredTextField(
              controller: _sitio,
              label: 'Sitio / Purok',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Employee'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_address == null) {
      CredSnackBar.show(context, 'Please complete the address', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).createStoreEmployee(
            storeOwnerId: widget.storeOwnerId,
            data: StoreEmployeeData(
              username: _username.text.trim(),
              password: _password.text,
              fullName: _fullName.text.trim(),
              province: _address!.province,
              municipality: _address!.municipality,
              barangay: _address!.barangay,
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              region: _address!.region,
              sitioPurok: _sitio.text.trim().isEmpty ? null : _sitio.text.trim(),
              position: _position.text.trim().isEmpty ? null : _position.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        CredSnackBar.show(context, '$e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
