class StoreProfile {
  const StoreProfile({
    this.id,
    required this.storeOwnerId,
    required this.storeName,
    this.ownerName,
    this.province,
    this.municipality,
    this.barangay,
    this.description,
    this.storeAddress,
    this.businessPermitNumber,
    this.businessHours,
    this.facebookPage,
    this.storeImage,
  });

  final String? id;
  final String storeOwnerId;
  final String storeName;
  final String? ownerName;
  final String? province;
  final String? municipality;
  final String? barangay;
  final String? description;
  final String? storeAddress;
  final String? businessPermitNumber;
  final String? businessHours;
  final String? facebookPage;
  /// Logo image — often a data URI / base64 string (Ionic `store_image`).
  final String? storeImage;

  factory StoreProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return StoreProfile(
      id: id,
      storeOwnerId: data['store_owner_id'] as String? ?? id,
      storeName: data['store_name'] as String? ?? '',
      ownerName: data['owner_name'] as String?,
      province: data['province'] as String?,
      municipality: data['municipality'] as String?,
      barangay: data['barangay'] as String?,
      description: data['store_description'] as String?,
      storeAddress: data['store_address'] as String?,
      businessPermitNumber: data['business_permit_number'] as String?,
      businessHours: data['business_hours'] as String?,
      facebookPage: data['facebook_page'] as String?,
      storeImage: data['store_image'] as String?,
    );
  }
}
