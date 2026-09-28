import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

class AdminDetailRow extends StatelessWidget {
  const AdminDetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: CredTheme.subtitleText, fontSize: 13)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
