/// Store branding used on receipts (Ionic `getStoreInfoForReceipt` parity).
class ReceiptStoreInfo {
  const ReceiptStoreInfo({
    required this.name,
    this.logoUrl,
    this.receiptHeader,
    this.receiptFooter = 'Thank you for your purchase!',
  });

  final String name;
  /// HTTP URL or data-URI / raw base64 (`store_profiles.store_image`).
  final String? logoUrl;
  final String? receiptHeader;
  final String receiptFooter;

  static const fallback = ReceiptStoreInfo(name: 'Store');
}
