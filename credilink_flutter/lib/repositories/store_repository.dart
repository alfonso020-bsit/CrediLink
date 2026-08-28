import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';

class StoreRepository {
  StoreRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<StoreProfile?> getStore(String storeOwnerId) async {
    final doc = await _firestore.collection('store_profiles').doc(storeOwnerId).get();
    if (!doc.exists) return null;
    return StoreProfile.fromFirestore(doc.id, doc.data()!);
  }

  Future<List<StoreProfile>> getAllStores() async {
    final snap = await _firestore.collection('store_profiles').get();
    return snap.docs.map((d) => StoreProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> updateStoreProfile({
    required String storeOwnerId,
    String? description,
    String? storeAddress,
    String? businessPermitNumber,
    String? businessHours,
    String? facebookPage,
  }) async {
    await _firestore.collection('store_profiles').doc(storeOwnerId).set({
      if (description != null) 'store_description': description,
      if (storeAddress != null) 'store_address': storeAddress,
      if (businessPermitNumber != null) 'business_permit_number': businessPermitNumber,
      if (businessHours != null) 'business_hours': businessHours,
      if (facebookPage != null) 'facebook_page': facebookPage,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
