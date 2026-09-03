import 'package:flutter/material.dart';

import '../../../core/theme/auth_theme.dart';
import '../../../models/user_role.dart';

class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.roles,
    required this.selectedRole,
    required this.onChanged,
  });

  final List<UserRole> roles;
  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: AuthTheme.inputBackground,
        borderRadius: BorderRadius.circular(AuthTheme.inputRadius),
        border: Border.all(color: AuthTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: roles.map((role) {
          final isSelected = role == selectedRole;
          return Expanded(
            child: Material(
              color: isSelected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onChanged(role),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(
                        role == UserRole.storeOwner
                            ? Icons.storefront
                            : Icons.person_outline,
                        color: isSelected ? Colors.white : AuthTheme.subtitleText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AuthTheme.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
