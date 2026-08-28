import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ph_address.dart';

class LocationRepository {
  Map<String, dynamic>? _data;

  Future<Map<String, dynamic>> loadData() async {
    if (_data != null) return _data!;
    final raw = await rootBundle.loadString('assets/data/phil.json');
    _data = json.decode(raw) as Map<String, dynamic>;
    return _data!;
  }

  Future<List<PhRegion>> getRegions() async {
    final data = await loadData();
    return data.entries
        .map((e) => PhRegion(
              code: e.key,
              name: (e.value as Map)['region_name'] as String,
            ))
        .toList();
  }

  Future<List<String>> getProvinces(String regionCode) async {
    final data = await loadData();
    final region = data[regionCode] as Map<String, dynamic>?;
    if (region == null) return [];
    final provinces = region['province_list'] as Map<String, dynamic>;
    return provinces.keys.toList()..sort();
  }

  Future<List<String>> getMunicipalities(String regionCode, String province) async {
    final data = await loadData();
    final provinces =
        (data[regionCode] as Map)['province_list'] as Map<String, dynamic>;
    final munis =
        (provinces[province] as Map)['municipality_list'] as Map<String, dynamic>;
    return munis.keys.toList()..sort();
  }

  Future<List<String>> getBarangays(
    String regionCode,
    String province,
    String municipality,
  ) async {
    final data = await loadData();
    final provinces =
        (data[regionCode] as Map)['province_list'] as Map<String, dynamic>;
    final munis =
        (provinces[province] as Map)['municipality_list'] as Map<String, dynamic>;
    final barangays =
        (munis[municipality] as Map)['barangay_list'] as List<dynamic>;
    return barangays.cast<String>()..sort();
  }

  /// Finds region code/name for a province name (v1 LocationService parity).
  ({String regionCode, String regionName})? getRegionByProvince(String province) {
    if (_data == null) return null;
    for (final entry in _data!.entries) {
      final region = entry.value as Map<String, dynamic>;
      final provinces = region['province_list'] as Map<String, dynamic>?;
      if (provinces != null && provinces.containsKey(province)) {
        return (
          regionCode: entry.key,
          regionName: region['region_name'] as String? ?? '',
        );
      }
    }
    return null;
  }
}
