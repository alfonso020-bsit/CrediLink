import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class BarcodeInputCard extends StatelessWidget {
  const BarcodeInputCard({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onScan,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CredTheme.radiusCard);

    return Material(
      color: CredTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: CredTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CredTheme.spaceMd,
          CredTheme.spaceSm,
          CredTheme.spaceXs,
          CredTheme.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Scan or enter barcode',
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            if (onScan != null)
              IconButton(
                tooltip: 'Scan barcode',
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner, color: CredTheme.primary),
              ),
            IconButton(
              tooltip: 'Look up',
              onPressed: onSubmit,
              icon: const Icon(Icons.search, color: CredTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
