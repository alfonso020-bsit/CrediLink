import 'package:flutter/material.dart';

import '../../../models/customer_profile.dart';
import '../filters/cred_search_field.dart';
import '../layout/cred_modal.dart';

class CustomerPickerSheet extends StatefulWidget {
  const CustomerPickerSheet({
    super.key,
    required this.customers,
    this.onRegisterNew,
  });

  final List<CustomerProfile> customers;
  final VoidCallback? onRegisterNew;

  static Future<CustomerProfile?> show(
    BuildContext context, {
    required List<CustomerProfile> customers,
    VoidCallback? onRegisterNew,
  }) {
    return showCredModal<CustomerProfile>(
      context: context,
      builder: (_) => credDraggableModalBody(
        child: CustomerPickerSheet(
          customers: customers,
          onRegisterNew: onRegisterNew,
        ),
      ),
    );
  }

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerProfile> get _filtered {
    if (_query.isEmpty) return widget.customers;
    final q = _query.toLowerCase();
    return widget.customers.where((c) {
      final name = (c.fullName ?? '').toLowerCase();
      final email = (c.email ?? '').toLowerCase();
      return name.contains(q) || email.contains(q) || c.customerId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Select Customer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          CredSearchField(
            controller: _searchController,
            hint: 'Search by name or email',
            onChanged: (v) => setState(() => _query = v),
          ),
          if (widget.onRegisterNew != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final register = widget.onRegisterNew;
                if (register != null) {
                  Future.microtask(register);
                }
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Register New Customer'),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No customers found'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final customer = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (customer.fullName ?? customer.customerId).substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(customer.fullName ?? customer.customerId),
                        subtitle: Text(customer.email ?? customer.customerId),
                        onTap: () => Navigator.pop(context, customer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
