import 'dart:convert';

import 'package:http/http.dart' as http;

class ExternalProductInfo {
  const ExternalProductInfo({
    required this.name,
    this.brand = '',
    this.category = '',
    this.description = '',
    this.imageUrl = '',
  });

  final String name;
  final String brand;
  final String category;
  final String description;
  final String imageUrl;
}

class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.success,
    this.product,
    this.message = '',
    this.source = '',
  });

  final bool success;
  final ExternalProductInfo? product;
  final String message;
  final String source;
}

class BarcodeLookupService {
  Future<BarcodeLookupResult> lookup(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) {
      return const BarcodeLookupResult(success: false, message: 'Empty barcode');
    }

    final off = await _tryOpenFoodFacts(clean);
    if (off.success) return off;

    return BarcodeLookupResult(success: false, message: off.message);
  }

  Future<BarcodeLookupResult> _tryOpenFoodFacts(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      );

      if (response.statusCode != 200) {
        return const BarcodeLookupResult(success: false, message: 'Open Food Facts API error');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) {
        return const BarcodeLookupResult(success: false, message: 'Not found in Open Food Facts');
      }

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) {
        return const BarcodeLookupResult(success: false, message: 'Not found in Open Food Facts');
      }

      var description = product['generic_name'] as String? ??
          product['product_name'] as String? ??
          'Product with barcode $barcode';
      final quantity = product['quantity'] as String?;
      if (quantity != null && quantity.isNotEmpty) {
        description = '$description | $quantity';
      }

      final imageUrl = product['image_url'] as String? ??
          product['image_front_url'] as String? ??
          '';

      return BarcodeLookupResult(
        success: true,
        source: 'open_food_facts',
        message: 'Product information retrieved from Open Food Facts',
        product: ExternalProductInfo(
          name: _cleanName(product['product_name'] as String? ??
              product['product_name_en'] as String? ??
              'Product $barcode'),
          brand: _cleanName(product['brands'] as String? ?? product['brand_owner'] as String? ?? ''),
          category: _determineCategory(product),
          description: description,
          imageUrl: imageUrl,
        ),
      );
    } catch (_) {
      return const BarcodeLookupResult(success: false, message: 'Open Food Facts API error');
    }
  }

  String _cleanName(String value) => value.trim();

  String _determineCategory(Map<String, dynamic> product) {
    final categories = product['categories'] as String?;
    if (categories != null && categories.isNotEmpty) {
      final parts = categories.split(',');
      return parts.first.trim();
    }
    final tags = product['categories_tags'] as List?;
    if (tags != null && tags.isNotEmpty) {
      return tags.first.toString().replaceAll('en:', '').replaceAll('-', ' ');
    }
    return 'General';
  }
}
