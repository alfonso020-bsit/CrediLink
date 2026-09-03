import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/auth_theme.dart';
import '../../../core/theme/cred_theme.dart';
import 'cred_buttons.dart';

class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AuthDivider(label: "Don't have an account?"),
        CredOutlineButton(
          label: 'Create account',
          icon: Icons.person_add_outlined,
          onPressed: () => context.go('/register'),
        ),
        const SizedBox(height: CredTheme.spaceMd),
        const Text(
          'Staff accounts are created by your store or administrator.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AuthTheme.subtitleText,
          ),
        ),
      ],
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CredTheme.spaceMd),
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
