class PhRegion {
  const PhRegion({required this.code, required this.name});
  final String code;
  final String name;
}

class PhAddress {
  const PhAddress({
    this.region,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.sitioPurok,
  });

  final String? region;
  final String province;
  final String municipality;
  final String barangay;
  final String? sitioPurok;

  String get display =>
      [region, province, municipality, barangay, sitioPurok]
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
}
