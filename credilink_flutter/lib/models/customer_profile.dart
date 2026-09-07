class CustomerProfile {
  const CustomerProfile({
    required this.customerId,
    this.fullName,
    this.email,
    this.phoneNumber,
    this.province,
    this.municipality,
    this.barangay,
  });

  final String customerId;
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? province;
  final String? municipality;
  final String? barangay;

  factory CustomerProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return CustomerProfile(
      customerId: data['customer_id'] as String? ?? data['user_id'] as String? ?? id,
      fullName: data['full_name'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phone_number'] as String?,
      province: data['province'] as String?,
      municipality: data['municipality'] as String?,
      barangay: data['barangay'] as String?,
    );
  }
}
