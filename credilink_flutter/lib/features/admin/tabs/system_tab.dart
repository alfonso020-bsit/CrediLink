import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';
import '../../../repositories/repositories.dart';
import '../../../shared/widgets/common/cred_async_view.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/common/info_banner.dart';
import '../../../shared/widgets/layout/cred_profile_card.dart';
import '../../../shared/widgets/layout/cred_section.dart';
import '../../../shared/widgets/layout/cred_status_chip.dart';
import '../../../shared/widgets/layout/cred_surface_tile.dart';
import '../../../shared/widgets/layout/cred_tab_page_layout.dart';
import '../../../shared/widgets/settings/profile_settings_sheet.dart';

class AdminSystemTab extends ConsumerWidget {
  const AdminSystemTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return CredAsyncView<UserProfile?>(
      asyncValue: profileAsync,
      emptyMessage: 'Not logged in',
      builder: (p) {
        if (p == null) return const EmptyState(message: 'Not logged in');

        final address = [
          p.sitioPurok,
          p.barangay,
          p.municipality,
          p.province,
        ].whereType<String>().where((e) => e.isNotEmpty).join(', ');

        final subtitleParts = [
          if (address.isNotEmpty) address,
          if (p.phoneNumber != null && p.phoneNumber!.trim().isNotEmpty) p.phoneNumber!,
        ];

        return CredTabPageLayout(
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            await ref.read(currentProfileProvider.future);
          },
          children: [
            const SizedBox(height: CredTheme.spaceMd),
            CredProfileCard(
              fullName: p.fullName,
              role: UserRole.admin,
              subtitle: subtitleParts.isEmpty ? null : subtitleParts.join('\n'),
              imageUrl: p.profileImage,
              onTap: () => ProfileSettingsSheet.show(context, p),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Account',
              subtitle: 'Profile details',
              child: Column(
                children: [
                  CredSurfaceTile(
                    leading: const Icon(Icons.alternate_email, color: CredTheme.primary),
                    title: const Text('Username'),
                    subtitle: Text(p.username),
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  CredSurfaceTile(
                    leading: const Icon(Icons.email_outlined, color: CredTheme.primary),
                    title: const Text('Email'),
                    subtitle: Text(p.email ?? 'N/A'),
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  CredSurfaceTile(
                    leading: const Icon(Icons.phone_outlined, color: CredTheme.primary),
                    title: const Text('Phone'),
                    subtitle: Text(p.phoneNumber ?? 'N/A'),
                  ),
                  const SizedBox(height: CredTheme.spaceXs),
                  CredSurfaceTile(
                    leading: const Icon(Icons.verified_user_outlined, color: CredTheme.primary),
                    title: const Text('Status'),
                    trailing: CredStatusChip.active(isActive: p.isActive, compact: true),
                  ),
                  if (p.createdAt != null) ...[
                    const SizedBox(height: CredTheme.spaceXs),
                    CredSurfaceTile(
                      leading: const Icon(Icons.calendar_today_outlined, color: CredTheme.primary),
                      title: const Text('Member since'),
                      subtitle: Text(DateFormat.yMMMd().format(p.createdAt!)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CredTheme.spaceLg),
            CredSection(
              title: 'Security',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    message:
                        'Password changes are handled through Firebase Auth. Use Forgot Password on the login screen to reset your password via email.',
                  ),
                  const SizedBox(height: CredTheme.spaceSm),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/forgot-password'),
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Reset Password'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
