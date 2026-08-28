class BulkOption {
  const BulkOption({
    required this.label,
    required this.piecesPerBulk,
    required this.price,
  });

  final String label;
  final int piecesPerBulk;
  final double price;

  factory BulkOption.fromMap(Map<String, dynamic> data) {
    return BulkOption(
      label: data['label'] as String? ?? data['unit'] as String? ?? 'bulk',
      piecesPerBulk: (data['pieces_per_bulk'] as num?)?.toInt() ?? 1,
      price: (data['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'pieces_per_bulk': piecesPerBulk,
        'price': price,
      };
}
