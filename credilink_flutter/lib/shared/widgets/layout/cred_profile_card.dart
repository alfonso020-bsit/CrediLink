import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/user_role.dart';
import '../common/cred_avatar.dart';

class CredProfileCard extends StatelessWidget {
  const CredProfileCard({
    super.key,
    required this.fullName,
    this.role,
    this.subtitle,
    this.storeName,
    this.position,
    this.imageUrl,
    this.onTap,
  });

  final String fullName;
  final UserRole? role;
  final String? subtitle;
  final String? storeName;
  final String? position;
  final String? imageUrl;
  final VoidCallback? onTap;

  bool get _isStoreOwner => role == UserRole.storeOwner;

  String get _title {
    if (_isStoreOwner) {
      final name = storeName?.trim();
      if (name != null && name.isNotEmpty) return name;
      return 'My Store';
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CredTheme.radiusCard);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _isStoreOwner
                  ? CredTheme.primary.withValues(alpha: 0.18)
                  : CredTheme.border,
            ),
            // Opaque mixes — avoid translucent washes that look mottled when scrolled.
            gradient: _isStoreOwner
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(CredTheme.cardBackground, CredTheme.primary, 0.12)!,
                      Color.lerp(CredTheme.cardBackground, CredTheme.primary, 0.05)!,
                      CredTheme.cardBackground,
                    ],
                  )
                : null,
            color: _isStoreOwner ? null : CredTheme.cardBackground,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              _isStoreOwner ? CredTheme.spaceLg : CredTheme.spaceMd,
            ),
            child: Row(
              children: [
                CredAvatar(name: _title, imageUrl: imageUrl, radius: _isStoreOwner ? 32 : 28),
                const SizedBox(width: CredTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: _isStoreOwner
                            ? CredTheme.pageTitle(context)
                            : Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: CredTheme.titleText,
                                ),
                      ),
                      if (_isStoreOwner) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Welcome back, $fullName',
                          style: CredTheme.bodyMutedStyle(context),
                        ),
                      ] else ...[
                        if (role != null) ...[
                          const SizedBox(height: 4),
                          _RoleBadge(label: role!.displayName),
                        ],
                        if (storeName != null && storeName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Working at $storeName',
                            style: CredTheme.bodyMutedStyle(context),
                          ),
                        ],
                        if (position != null && position!.isNotEmpty)
                          Text(position!, style: CredTheme.bodyMutedStyle(context)),
                      ],
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: CredTheme.subtitleText,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: CredTheme.primary.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CredTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CredTheme.radiusChip),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CredTheme.primary),
      ),
    );
  }
}
