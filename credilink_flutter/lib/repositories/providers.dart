import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/store_scope.dart';
import '../models/debt_record.dart';
import '../models/product.dart';
import '../models/receipt_store_info.dart';
import '../models/sale_record.dart';
import '../models/store_profile.dart';
import '../models/user_profile.dart';
import 'admin_repository.dart';
import 'auth_repository.dart';
import 'customer_repository.dart';
import 'debt_customer_repository.dart';
import 'employee_repository.dart';
import 'location_repository.dart';
import 'payment_repository.dart';
import 'product_repository.dart';
import 'store_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.read(authRepositoryProvider).getCurrentProfile();
});

final authServiceProvider = authRepositoryProvider;

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(FirebaseFirestore.instance);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(FirebaseFirestore.instance);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(FirebaseFirestore.instance);
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(FirebaseFirestore.instance);
});

final debtCustomerRepositoryProvider = Provider<DebtCustomerRepository>((ref) {
  return DebtCustomerRepository(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final storeProductsProvider = FutureProvider.family<List<Product>, String>((ref, storeOwnerId) {
  return ref.watch(productRepositoryProvider).getProductsByStore(storeOwnerId);
});

final storeDebtsProvider = FutureProvider.family<List<DebtRecord>, String>((ref, storeOwnerId) {
  return ref.watch(paymentRepositoryProvider).getDebtsByStore(storeOwnerId);
});

final currentStoreProductsProvider = FutureProvider<List<Product>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(productRepositoryProvider).getProductsByStore(resolveStoreOwnerId(profile));
});

final currentStoreDebtsProvider = FutureProvider<List<DebtRecord>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  final storeId = resolveStoreOwnerId(profile);
  return ref.read(paymentRepositoryProvider).getDebtsByStore(storeId);
});

final storeTodayActivityProvider = FutureProvider.family<Map<String, int>, String>((ref, storeOwnerId) {
  return ref.watch(adminRepositoryProvider).getTodayActivityForStore(storeOwnerId);
});

final storeSalesProvider = FutureProvider.family<List<SaleRecord>, String>((ref, storeOwnerId) {
  return ref.watch(productRepositoryProvider).getSalesForStore(storeOwnerId);
});

final storeEmployeesProvider = FutureProvider.family<List<UserProfile>, String>((ref, storeOwnerId) {
  return ref.watch(employeeRepositoryProvider).getEmployeesByStore(storeOwnerId);
});

final currentStoreTodayActivityProvider = FutureProvider<Map<String, int>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return {'transactions': 0, 'newDebts': 0, 'payments': 0};
  return ref.read(adminRepositoryProvider).getTodayActivityForStore(resolveStoreOwnerId(profile));
});

final currentStoreSalesProvider = FutureProvider<List<SaleRecord>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(productRepositoryProvider).getSalesForStore(resolveStoreOwnerId(profile));
});

final currentStoreEmployeesProvider = FutureProvider<List<UserProfile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(employeeRepositoryProvider).getEmployeesByStore(resolveStoreOwnerId(profile));
});

/// Store name + logo for receipts (owner `store_name` + `store_profiles.store_image`).
final receiptStoreInfoProvider =
    FutureProvider.family<ReceiptStoreInfo, String>((ref, storeOwnerId) async {
  if (storeOwnerId.isEmpty) return ReceiptStoreInfo.fallback;

  final owner = await ref.read(authRepositoryProvider).getUserProfileById(storeOwnerId);
  final store = await ref.watch(storeProfileProvider(storeOwnerId).future);

  final ownerName = owner?.storeName?.trim();
  final profileName = store?.storeName.trim();
  final name = (ownerName != null && ownerName.isNotEmpty)
      ? ownerName
      : (profileName != null && profileName.isNotEmpty)
          ? profileName
          : (owner != null && owner.fullName.trim().isNotEmpty)
              ? "${owner.fullName.trim()}'s Store"
              : 'Store';

  final logo = store?.storeImage?.trim();
  final header = store?.description?.trim();

  return ReceiptStoreInfo(
    name: name,
    logoUrl: (logo != null && logo.isNotEmpty) ? logo : null,
    receiptHeader: (header != null && header.isNotEmpty) ? header : null,
  );
});

final storeProfileProvider = FutureProvider.family<StoreProfile?, String>((ref, storeOwnerId) async {
  if (storeOwnerId.isEmpty) return null;
  return ref.read(storeRepositoryProvider).getStore(storeOwnerId);
});

final userProfileByIdProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return ref.read(authRepositoryProvider).getUserProfileById(userId);
});

/// Customer-scoped debts by user id.
final customerDebtsProvider = FutureProvider.family<List<DebtRecord>, String>((ref, customerId) {
  return ref.watch(paymentRepositoryProvider).getDebtsByCustomer(customerId);
});

final currentCustomerDebtsProvider = FutureProvider<List<DebtRecord>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(customerDebtsProvider(profile.id).future);
});

final currentCustomerSalesProvider = FutureProvider<List<SaleRecord>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(productRepositoryProvider).getSalesByCustomer(
        profile.id,
        customerName: profile.fullName,
      );
});

final allStoresProvider = FutureProvider<List<StoreProfile>>((ref) {
  return ref.watch(storeRepositoryProvider).getAllStores();
});

/// Debts + store profiles + owner phones for customer Debts/Alerts tabs.
final currentCustomerDebtsBundleProvider = FutureProvider<
    ({
      List<DebtRecord> debts,
      Map<String, StoreProfile> stores,
      Map<String, String> storePhones,
    })>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return (debts: <DebtRecord>[], stores: <String, StoreProfile>{}, storePhones: <String, String>{});
  }

  final debts = await ref.watch(customerDebtsProvider(profile.id).future);
  final storeIds = debts.map((d) => d.storeOwnerId).toSet();
  final stores = <String, StoreProfile>{};
  for (final id in storeIds) {
    final store = await ref.read(storeRepositoryProvider).getStore(id);
    if (store != null) stores[id] = store;
  }

  final authRepo = ref.read(authRepositoryProvider);
  final storePhones = <String, String>{};
  for (final id in storeIds) {
    final owner = await authRepo.getUserProfileById(id);
    final phone = owner?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) storePhones[id] = phone;
  }

  return (debts: debts, stores: stores, storePhones: storePhones);
});

final currentCustomerHistoryBundleProvider = FutureProvider<
    ({
      List<SaleRecord> sales,
      Map<String, StoreProfile> stores,
    })>((ref) async {
  final sales = await ref.watch(currentCustomerSalesProvider.future);
  final storeIds = sales.map((s) => s.storeOwnerId).toSet();
  final stores = <String, StoreProfile>{};
  for (final id in storeIds) {
    final store = await ref.read(storeRepositoryProvider).getStore(id);
    if (store != null) stores[id] = store;
  }
  return (sales: sales, stores: stores);
});
