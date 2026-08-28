import 'package:flutter/material.dart';

class CredFilterChipData {
  const CredFilterChipData({required this.label, this.onDeleted});

  final String label;
  final VoidCallback? onDeleted;
}

class CredFilterChips extends StatelessWidget {
  const CredFilterChips({
    super.key,
    required this.chips,
    this.onClearAll,
    this.clearLabel = 'Clear',
  });

  final List<CredFilterChipData> chips;
  final VoidCallback? onClearAll;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty && onClearAll == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...chips.map(
          (c) => Chip(
            label: Text(c.label),
            onDeleted: c.onDeleted,
          ),
        ),
        if (onClearAll != null)
          ActionChip(label: Text(clearLabel), onPressed: onClearAll),
      ],
    );
  }
}
