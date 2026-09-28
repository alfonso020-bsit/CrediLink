import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/auth/secondary_auth.dart';
import '../core/errors/app_exception.dart';
import '../models/user_role.dart';
import 'location_repository.dart';

class DebtCustomerRegistrationData {
  const DebtCustomerRegistrationData({
    required this.fullName,
    required this.phoneNumber,
    required this.municipality,
    required this.barangay,
    this.email,
    this.sitioPurok,
    this.username,
    this.password,
  });

  final String fullName;
  final String phoneNumber;
  final String municipality;
  final String barangay;
  final String? email;
  final String? sitioPurok;
  final String? username;
  final String? password;
}

/// POS debt-customer registration via Firebase Auth (no password_hash).
class DebtCustomerRepository {
  DebtCustomerRepository({
    required FirebaseFirestore firestore,
    required LocationRepository locationRepository,
  })  : _firestore = firestore,
        _locationRepository = locationRepository;

  final FirebaseFirestore _firestore;
  final LocationRepository _locationRepository;

  Future<void> registerDebtCustomer({
    required String storeOwnerId,
    required String storeOwnerProvince,
    String? storeOwnerRegion,
    required DebtCustomerRegistrationData customerData,
  }) async {
    await _locationRepository.loadData();
    final regionInfo = _locationRepository.getRegionByProvince(storeOwnerProvince);
    if (regionInfo == null) {
      throw const AuthException('Store owner province is not configured.');
    }

    final municipalities = await _locationRepository.getMunicipalities(
      regionInfo.regionCode,
      storeOwnerProvince,
    );
    if (!municipalities.contains(customerData.municipality)) {
      throw AuthException(
        'Selected municipality "${customerData.municipality}" does not belong to $storeOwnerProvince.',
      );
    }

    final barangays = await _locationRepository.getBarangays(
      regionInfo.regionCode,
      storeOwnerProvince,
      customerData.municipality,
    );
    if (!barangays.contains(customerData.barangay)) {
      throw AuthException(
        'Selected barangay "${customerData.barangay}" does not belong to ${customerData.municipality}.',
      );
    }

    final cleanPhone = customerData.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final username = (customerData.username?.trim().isNotEmpty ?? false)
        ? customerData.username!.trim().toLowerCase()
        : 'cust_$cleanPhone';

    final password = customerData.password?.trim() ?? '';
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters long');
    }

    if (await _isUsernameTaken(username)) {
      throw AuthException('Username "$username" already exists.');
    }

    final email = (customerData.email != null && customerData.email!.trim().isNotEmpty)
        ? customerData.email!.trim()
        : '$username@customers.credilink.local';

    if (await _isEmailTaken(email)) {
      throw const AuthException('Email already exists');
    }

    try {
      await SecondaryAuth.createUser(
        email: email,
        password: password,
        writeProfile: (uid) async {
          await _firestore.collection('all_users').doc(uid).set({
            'username': username,
            'full_name': customerData.fullName.trim(),
            'email': email,
            'phone_number': customerData.phoneNumber.trim(),
            'region': storeOwnerRegion ?? regionInfo.regionName,
            'province': storeOwnerProvince,
            'municipality': customerData.municipality,
            'barangay': customerData.barangay,
            'sitio_purok': customerData.sitioPurok?.trim() ?? '',
            'role': UserRole.customer.value,
            'status': 'active',
            'store_owner_id': storeOwnerId,
            'firebase_uid': uid,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          await _firestore.collection('customer_profiles').doc(uid).set({
            'user_id': uid,
            'customer_id': uid,
            'store_owner_id': storeOwnerId,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<bool> _isUsernameTaken(String username) async {
    final snap = await _firestore
        .collection('all_users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> _isEmailTaken(String email) async {
    for (final candidate in {email, email.toLowerCase()}) {
      final snap = await _firestore
          .collection('all_users')
          .where('email', isEqualTo: candidate)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return true;
    }
    return false;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email already exists';
      case 'weak-password':
        return 'Password must be at least 6 characters long';
      case 'invalid-email':
        return 'Enter a valid email';
      default:
        return e.message ?? "Couldn't register customer. Try again.";
    }
  }
}
