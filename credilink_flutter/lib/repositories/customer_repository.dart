import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_profile.dart';
import '../models/user_profile.dart';

class CustomerRepository {
  CustomerRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final doc = await _firestore.collection('customer_profiles').doc(userId).get();
    return doc.data();
  }

  Future<CustomerProfile?> getCustomerProfile(String customerId) async {
    final byDocId = await _firestore.collection('customer_profiles').doc(customerId).get();
    if (byDocId.exists && byDocId.data() != null) {
      return CustomerProfile.fromFirestore(byDocId.id, byDocId.data()!);
    }

    final snap = await _firestore
        .collection('customer_profiles')
        .where('customer_id', isEqualTo: customerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return CustomerProfile.fromFirestore(doc.id, doc.data());
  }

  Future<({UserProfile user, CustomerProfile? profile})> getCompleteCustomerInfo(
    String customerId,
  ) async {
    final userDoc = await _firestore.collection('all_users').doc(customerId).get();
    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('Customer not found');
    }
    final profile = await getCustomerProfile(customerId);
    return (
      user: UserProfile.fromFirestore(userDoc.id, userDoc.data()!),
      profile: profile,
    );
  }

  Future<List<UserProfile>> searchCustomersByStore(
    String storeOwnerId, {
    String searchTerm = '',
  }) async {
    final snap = await _firestore
        .collection('all_users')
        .where('role', isEqualTo: 'Customer')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();

    var customers =
        snap.docs.map((d) => UserProfile.fromFirestore(d.id, d.data())).toList();

    final term = searchTerm.trim().toLowerCase();
    if (term.isEmpty) return customers;

    return customers.where((c) {
      return c.fullName.toLowerCase().contains(term) ||
          (c.phoneNumber?.contains(term) ?? false) ||
          (c.email?.toLowerCase().contains(term) ?? false) ||
          c.username.toLowerCase().contains(term);
    }).toList();
  }
}
