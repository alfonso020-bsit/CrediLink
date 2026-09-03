import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';

class StoreRepository {
  StoreRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<StoreProfile?> getStore(String storeOwnerId) async {
    // Newer docs may use owner id as the document id.
    final byId = await _firestore.collection('store_profiles').doc(storeOwnerId).get();
    if (byId.exists && byId.data() != null) {
      return StoreProfile.fromFirestore(byId.id, byId.data()!);
    }

    // Ionic creates auto-ids and looks up by store_owner_id.
    final snap = await _firestore
        .collection('store_profiles')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return StoreProfile.fromFirestore(doc.id, doc.data());
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
    String? storeImage,
    bool clearStoreImage = false,
  }) async {
    final existing = await getStore(storeOwnerId);
    final docId = existing?.id ?? storeOwnerId;

    await _firestore.collection('store_profiles').doc(docId).set({
      'store_owner_id': storeOwnerId,
      if (description != null) 'store_description': description,
      if (storeAddress != null) 'store_address': storeAddress,
      if (businessPermitNumber != null) 'business_permit_number': businessPermitNumber,
      if (businessHours != null) 'business_hours': businessHours,
      if (facebookPage != null) 'facebook_page': facebookPage,
      if (clearStoreImage) 'store_image': '',
      if (!clearStoreImage && storeImage != null) 'store_image': storeImage,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
