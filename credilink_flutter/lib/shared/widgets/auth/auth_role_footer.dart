import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/auth_theme.dart';
import '../../../models/user_role.dart';
import 'cred_buttons.dart';

/// v1 login additional-section: register CTA or role info boxes.
class AuthRoleFooter extends StatelessWidget {
  const AuthRoleFooter({
    super.key,
    required this.selectedRole,
  });

  final UserRole selectedRole;

  @override
  Widget build(BuildContext context) {
    if (selectedRole == UserRole.customer || selectedRole == UserRole.storeOwner) {
      final roleLabel = selectedRole == UserRole.customer ? 'Customer' : 'Store Owner';
      final roleParam = selectedRole == UserRole.customer ? 'customer' : 'storeowner';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthDivider(label: 'New $roleLabel?'),
          CredOutlineButton(
            label: 'Create $roleLabel Account',
            icon: Icons.person_add_outlined,
            onPressed: () => context.go('/register?role=$roleParam'),
          ),
          if (selectedRole == UserRole.storeOwner) ...[
            const SizedBox(height: 16),
            _InfoBox(
              icon: Icons.storefront_outlined,
              message:
                  'Store Owner accounts can manage their store and view customer transactions.',
            ),
          ],
        ],
      );
    }

    if (selectedRole == UserRole.admin) {
      return _InfoBox(
        icon: Icons.info_outline,
        message: 'Admin accounts are system-defined.',
      );
    }

    if (selectedRole == UserRole.employee) {
      return _InfoBox(
        icon: Icons.info_outline,
        message: 'Employee accounts are created by administrators.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AuthTheme.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AuthTheme.subtitleText,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AuthTheme.border)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthTheme.infoBoxBg,
        borderRadius: BorderRadius.circular(AuthTheme.inputRadius),
        border: Border.all(color: AuthTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, height: 1.5, color: AuthTheme.subtitleText),
            ),
          ),
        ],
      ),
    );
  }
}
