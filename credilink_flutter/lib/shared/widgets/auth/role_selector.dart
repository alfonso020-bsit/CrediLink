import 'package:flutter/material.dart';

import '../../../core/theme/auth_theme.dart';
import '../../../models/user_role.dart';

enum RoleSelectorStyle { chips, grid, toggle }

class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.roles,
    required this.selectedRole,
    required this.onChanged,
    this.style = RoleSelectorStyle.chips,
    this.label = 'Select Role',
  });

  final List<UserRole> roles;
  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;
  final RoleSelectorStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (style == RoleSelectorStyle.toggle) {
      return _RoleToggle(
        roles: roles,
        selectedRole: selectedRole,
        onChanged: onChanged,
      );
    }

    if (style == RoleSelectorStyle.grid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AuthTheme.titleText,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 360 ? 2 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: roles.map((role) {
                  return _RoleGridButton(
                    role: role,
                    isSelected: role == selectedRole,
                    onTap: () => onChanged(role),
                  );
                }).toList(),
              );
            },
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: roles.map((role) {
        final isSelected = role == selectedRole;
        return ChoiceChip(
          label: Text(role.displayName),
          selected: isSelected,
          onSelected: (_) => onChanged(role),
        );
      }).toList(),
    );
  }
}

class _RoleGridButton extends StatelessWidget {
  const _RoleGridButton({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected ? primary : AuthTheme.roleInactiveBg,
      borderRadius: BorderRadius.circular(AuthTheme.roleRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuthTheme.roleRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuthTheme.roleRadius),
            border: Border.all(
              color: isSelected ? primary : AuthTheme.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconFor(role),
                size: 28,
                color: isSelected ? Colors.white : AuthTheme.subtitleText,
              ),
              const SizedBox(height: 6),
              Text(
                role.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AuthTheme.subtitleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({
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
                        _iconFor(role),
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

IconData _iconFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return Icons.shield;
    case UserRole.employee:
      return Icons.badge_outlined;
    case UserRole.customer:
      return Icons.person;
    case UserRole.storeOwner:
      return Icons.storefront;
  }
}
