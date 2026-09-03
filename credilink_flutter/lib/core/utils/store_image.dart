import 'dart:convert';
import 'dart:typed_data';

/// Decodes store logo from HTTP URL, data URI, or raw base64 (Ionic store_image).
Uint8List? decodeStoreImageBytes(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return null;

  try {
    final payload = value.contains(',') ? value.split(',').last : value;
    final normalized = payload.replaceAll(RegExp(r'\s'), '');
    if (normalized.isEmpty) return null;
    return base64Decode(normalized);
  } catch (_) {
    return null;
  }
}

bool isNetworkStoreImage(String? raw) {
  if (raw == null) return false;
  final value = raw.trim();
  return value.startsWith('http://') || value.startsWith('https://');
}
