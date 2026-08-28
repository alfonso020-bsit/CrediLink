import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.status,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.email,
    this.phoneNumber,
    this.region,
    this.sitioPurok,
    this.storeOwnerId,
    this.storeName,
    this.profileImage,
    this.position,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String status;
  final String? email;
  final String? phoneNumber;
  final String? region;
  final String province;
  final String municipality;
  final String barangay;
  final String? sitioPurok;
  final String? storeOwnerId;
  final String? storeName;
  final String? profileImage;
  final String? position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory UserProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      username: data['username'] as String? ?? '',
      fullName: data['full_name'] as String? ?? '',
      role: UserRole.fromValue(data['role'] as String? ?? 'Customer'),
      status: data['status'] as String? ?? 'inactive',
      email: data['email'] as String?,
      phoneNumber: data['phone_number'] as String?,
      region: data['region'] as String?,
      province: data['province'] as String? ?? '',
      municipality: data['municipality'] as String? ?? '',
      barangay: data['barangay'] as String? ?? '',
      sitioPurok: data['sitio_purok'] as String?,
      storeOwnerId: data['store_owner_id'] as String?,
      storeName: data['store_name'] as String?,
      profileImage: data['profile_image'] as String?,
      position: data['position'] as String?,
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'full_name': fullName,
      'role': role.value,
      'status': status,
      'email': email,
      'phone_number': phoneNumber,
      'region': region,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      'sitio_purok': sitioPurok,
      'store_owner_id': storeOwnerId,
      'store_name': storeName,
      'profile_image': profileImage,
      'position': position,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class RegisterData {
  const RegisterData({
    required this.role,
    required this.username,
    required this.email,
    required this.password,
    required this.fullName,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.phoneNumber,
    this.region,
    this.sitioPurok,
    this.storeName,
  });

  final UserRole role;
  final String username;
  final String email;
  final String password;
  final String fullName;
  final String? phoneNumber;
  final String? region;
  final String province;
  final String municipality;
  final String barangay;
  final String? sitioPurok;
  final String? storeName;
}
