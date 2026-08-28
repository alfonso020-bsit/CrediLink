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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(CredTheme.spaceMd),
          child: Row(
            children: [
              CredAvatar(name: fullName, imageUrl: imageUrl, radius: 28),
              const SizedBox(width: CredTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: Theme.of(context).textTheme.titleMedium),
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
                    if (subtitle != null) Text(subtitle!, style: CredTheme.bodyMutedStyle(context)),
                  ],
                ),
              ),
            ],
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
