import 'package:flutter/material.dart';

import '../../core/theme/cred_theme.dart';
import '../../models/debt_record.dart';
import '../../models/sale_record.dart';
import '../../models/store_profile.dart';
import '../../models/user_profile.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/auth_repository.dart';

class CustomerHelpers {
  static String fullAddress(UserProfile profile) {
    return '${profile.barangay}, ${profile.municipality}, ${profile.province}';
  }

  static String storeLocation(StoreProfile store) {
    if (store.storeAddress != null && store.storeAddress!.trim().isNotEmpty) {
      return store.storeAddress!.trim();
    }
    final parts = [
      if (store.barangay != null && store.barangay!.isNotEmpty) store.barangay,
      if (store.municipality != null && store.municipality!.isNotEmpty) store.municipality,
      if (store.province != null && store.province!.isNotEmpty) store.province,
    ];
    return parts.join(', ');
  }

  static bool isDebtOverdue(DebtRecord debt, PaymentRepository paymentRepo) {
    return paymentRepo.isDebtOverdue(debt);
  }

  static Color paymentStatusColor(String status) {
    switch (_normalizePaymentStatus(status)) {
      case 'paid':
        return CredTheme.success;
      case 'partially_paid':
        return CredTheme.warning;
      case 'unpaid':
        return CredTheme.danger;
      default:
        return CredTheme.subtitleText;
    }
  }

  static String paymentStatusLabel(String status) {
    switch (_normalizePaymentStatus(status)) {
      case 'paid':
        return 'Paid';
      case 'partially_paid':
        return 'Partial';
      case 'unpaid':
        return 'Unpaid';
      default:
        return status;
    }
  }

  /// Maps legacy aliases (`pending`, `partial`) to canonical payment_status.
  static String normalizePaymentStatus(String status) => _normalizePaymentStatus(status);

  static String _normalizePaymentStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return 'paid';
      case 'partially_paid':
      case 'partial':
        return 'partially_paid';
      case 'unpaid':
      case 'pending':
        return 'unpaid';
      default:
        return status.trim().toLowerCase();
    }
  }

  static String debtStatusLabel(DebtRecord debt, PaymentRepository paymentRepo) {
    if (debt.isPaid) return 'paid';
    if (isDebtOverdue(debt, paymentRepo)) return 'overdue';
    return debt.status;
  }

  static Map<String, List<DebtRecord>> groupDebtsByStore(List<DebtRecord> debts) {
    final grouped = <String, List<DebtRecord>>{};
    for (final debt in debts) {
      grouped.putIfAbsent(debt.storeOwnerId, () => []).add(debt);
    }
    return grouped;
  }

  static String saleTypeLabel(SaleRecord sale) {
    return sale.type == SaleType.cash ? 'Cash' : 'Credit';
  }

  static Future<Map<String, String>> loadStorePhones(
    AuthRepository authRepo,
    Iterable<String> storeOwnerIds,
  ) async {
    final phones = <String, String>{};
    for (final id in storeOwnerIds) {
      final owner = await authRepo.getUserProfileById(id);
      final phone = owner?.phoneNumber?.trim();
      if (phone != null && phone.isNotEmpty) {
        phones[id] = phone;
      }
    }
    return phones;
  }
}
