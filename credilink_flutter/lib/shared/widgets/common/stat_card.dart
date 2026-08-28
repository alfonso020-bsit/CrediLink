import 'package:flutter/material.dart';

import '../layout/cred_metric_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return CredMetricCard(label: label, value: value, icon: icon);
  }
}
