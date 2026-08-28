import 'package:flutter/material.dart';

import '../../../models/debt_record.dart';
import '../../../repositories/payment_repository.dart';
import '../customer_helpers.dart';

class DebtStatusBadge extends StatelessWidget {
  const DebtStatusBadge({
    super.key,
    required this.debt,
    required this.paymentRepo,
  });

  final DebtRecord debt;
  final PaymentRepository paymentRepo;

  @override
  Widget build(BuildContext context) {
    final overdue = CustomerHelpers.isDebtOverdue(debt, paymentRepo);
    final label = overdue ? 'Overdue' : CustomerHelpers.paymentStatusLabel(debt.paymentStatus);
    final color = overdue
        ? Colors.red
        : CustomerHelpers.paymentStatusColor(debt.paymentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
