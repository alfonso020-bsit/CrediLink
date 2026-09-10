import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/cred_theme.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/auth/auth_scaffold.dart';
import '../../shared/widgets/auth/cred_buttons.dart';

/// Shown on Flutter Web when a non-admin signs in.
/// Store Owner, Employee, and Customer should use the mobile app.
class UseMobileAppScreen extends ConsumerWidget {
  const UseMobileAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;

    return AuthScaffold(
      welcomeTitle: 'Use the mobile app',
      welcomeSubtitle: profile != null
          ? '${profile.role.displayName} accounts run on the CrediLink app'
          : 'This role is available on the CrediLink mobile app',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.phone_android_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: CredTheme.spaceMd),
          Text(
            'The web console is for platform admins only. '
            'Download or open the CrediLink mobile app to continue as a '
            'store owner, employee, or customer.',
            textAlign: TextAlign.center,
            style: CredTheme.bodyMutedStyle(context),
          ),
          const SizedBox(height: CredTheme.spaceLg),
          CredPrimaryButton(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(currentProfileProvider);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
