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

  /// Prefer store_name; fall back to owner-based label.
  String get displayName {
    final name = storeName.trim();
    if (name.isNotEmpty) return name;
    final owner = ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return "$owner's Store";
    return 'Store';
  }

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

  StoreProfile copyWith({
    String? id,
    String? storeOwnerId,
    String? storeName,
    String? ownerName,
    String? province,
    String? municipality,
    String? barangay,
    String? description,
    String? storeAddress,
    String? businessPermitNumber,
    String? businessHours,
    String? facebookPage,
    String? storeImage,
  }) {
    return StoreProfile(
      id: id ?? this.id,
      storeOwnerId: storeOwnerId ?? this.storeOwnerId,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      description: description ?? this.description,
      storeAddress: storeAddress ?? this.storeAddress,
      businessPermitNumber: businessPermitNumber ?? this.businessPermitNumber,
      businessHours: businessHours ?? this.businessHours,
      facebookPage: facebookPage ?? this.facebookPage,
      storeImage: storeImage ?? this.storeImage,
    );
  }
}
