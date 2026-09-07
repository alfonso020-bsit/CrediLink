import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';

class StoreRepository {
  StoreRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<StoreProfile?> getStore(String storeOwnerId) async {
    Map<String, dynamic>? profileData;
    String? profileId;

    // Newer docs may use owner id as the document id.
    final byId = await _firestore.collection('store_profiles').doc(storeOwnerId).get();
    if (byId.exists && byId.data() != null) {
      profileId = byId.id;
      profileData = byId.data();
    } else {
      // Ionic creates auto-ids and looks up by store_owner_id.
      final snap = await _firestore
          .collection('store_profiles')
          .where('store_owner_id', isEqualTo: storeOwnerId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        profileId = snap.docs.first.id;
        profileData = snap.docs.first.data();
      }
    }

    final ownerDoc = await _firestore.collection('all_users').doc(storeOwnerId).get();
    final owner = ownerDoc.data();

    if (profileData == null && owner == null) return null;

    final profileName = (profileData?['store_name'] as String?)?.trim() ?? '';
    final ownerStoreName = (owner?['store_name'] as String?)?.trim() ?? '';
    final fullName = (owner?['full_name'] as String?)?.trim() ?? '';
    final resolvedName = profileName.isNotEmpty
        ? profileName
        : ownerStoreName.isNotEmpty
            ? ownerStoreName
            : (fullName.isNotEmpty ? "$fullName's Store" : 'Store');

    String? pick(String key) {
      final fromProfile = (profileData?[key] as String?)?.trim();
      if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
      final fromOwner = (owner?[key] as String?)?.trim();
      if (fromOwner != null && fromOwner.isNotEmpty) return fromOwner;
      return null;
    }

    return StoreProfile(
      id: profileId ?? storeOwnerId,
      storeOwnerId: storeOwnerId,
      storeName: resolvedName,
      ownerName: fullName.isNotEmpty ? fullName : null,
      province: pick('province'),
      municipality: pick('municipality'),
      barangay: pick('barangay'),
      description: profileData?['store_description'] as String?,
      storeAddress: profileData?['store_address'] as String?,
      businessPermitNumber: profileData?['business_permit_number'] as String?,
      businessHours: profileData?['business_hours'] as String?,
      facebookPage: profileData?['facebook_page'] as String?,
      storeImage: profileData?['store_image'] as String?,
    );
  }

  Future<List<StoreProfile>> getAllStores() async {
    // Ionic customer Products loads StoreOwners from all_users, then attaches store_profiles.
    final ownersSnap = await _firestore
        .collection('all_users')
        .where('role', isEqualTo: 'StoreOwner')
        .get();

    final profilesSnap = await _firestore.collection('store_profiles').get();
    final profileByOwnerId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in profilesSnap.docs) {
      final data = doc.data();
      final ownerId = data['store_owner_id'] as String? ?? doc.id;
      profileByOwnerId.putIfAbsent(ownerId, () => doc);
    }

    final stores = <StoreProfile>[];
    for (final ownerDoc in ownersSnap.docs) {
      final owner = ownerDoc.data();
      if ((owner['status'] as String?) == 'inactive') continue;

      final ownerId = ownerDoc.id;
      final profileDoc = profileByOwnerId[ownerId];
      final profileData = profileDoc?.data();

      // Same resolution as getStore: profile → owner store_name → full_name's Store.
      final profileName = (profileData?['store_name'] as String?)?.trim() ?? '';
      final ownerStoreName = (owner['store_name'] as String?)?.trim() ?? '';
      final fullName = (owner['full_name'] as String?)?.trim() ?? '';
      final resolvedName = profileName.isNotEmpty
          ? profileName
          : ownerStoreName.isNotEmpty
              ? ownerStoreName
              : (fullName.isNotEmpty ? "$fullName's Store" : 'Store');

      String? pick(String key) {
        final fromProfile = (profileData?[key] as String?)?.trim();
        if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
        final fromOwner = (owner[key] as String?)?.trim();
        if (fromOwner != null && fromOwner.isNotEmpty) return fromOwner;
        return null;
      }

      stores.add(
        StoreProfile(
          id: profileDoc?.id ?? ownerId,
          storeOwnerId: ownerId,
          storeName: resolvedName,
          ownerName: fullName.isNotEmpty ? fullName : null,
          province: pick('province'),
          municipality: pick('municipality'),
          barangay: pick('barangay'),
          description: profileData?['store_description'] as String?,
          storeAddress: profileData?['store_address'] as String?,
          businessPermitNumber: profileData?['business_permit_number'] as String?,
          businessHours: profileData?['business_hours'] as String?,
          facebookPage: profileData?['facebook_page'] as String?,
          storeImage: profileData?['store_image'] as String?,
        ),
      );
    }

    stores.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return stores;
  }

  Future<void> updateStoreProfile({
    required String storeOwnerId,
    String? storeName,
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
    final trimmedName = storeName?.trim();

    await _firestore.collection('store_profiles').doc(docId).set({
      'store_owner_id': storeOwnerId,
      if (trimmedName != null && trimmedName.isNotEmpty) 'store_name': trimmedName,
      if (description != null) 'store_description': description,
      if (storeAddress != null) 'store_address': storeAddress,
      if (businessPermitNumber != null) 'business_permit_number': businessPermitNumber,
      if (businessHours != null) 'business_hours': businessHours,
      if (facebookPage != null) 'facebook_page': facebookPage,
      if (clearStoreImage) 'store_image': '',
      if (!clearStoreImage && storeImage != null) 'store_image': storeImage,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (trimmedName != null && trimmedName.isNotEmpty) {
      await _firestore.collection('all_users').doc(storeOwnerId).set({
        'store_name': trimmedName,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
