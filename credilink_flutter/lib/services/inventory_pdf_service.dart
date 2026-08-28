import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/inventory_stats.dart';
import '../models/product.dart';

class InventoryPdfService {
  Future<void> exportInventory({
    required List<Product> products,
    required String storeName,
    required String ownerName,
  }) async {
    final active = products.where((p) => p.isActive).toList();
    final stats = computeInventoryStats(active);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final now = DateTime.now();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INVENTORY REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Store: $storeName'),
                pw.Text('Owner: $ownerName'),
                pw.Text('Generated: ${dateFormat.format(now)} ${timeFormat.format(now)}'),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Total: ${stats.total} | In Stock: ${stats.inStock} | Low Stock: ${stats.lowStock} | Out of Stock: ${stats.outOfStock}',
                ),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Product', 'Category', 'Stock', 'Price', 'Status'],
            data: active.map((p) {
              final status = switch (stockStatusFor(p)) {
                StockStatus.inStock => 'In Stock',
                StockStatus.lowStock => 'Low Stock',
                StockStatus.outOfStock => 'Out of Stock',
              };
              return [
                p.name,
                p.category,
                '${p.stockQuantity} ${p.unitOfMeasure}',
                '₱${p.sellingPrice.toStringAsFixed(2)}',
                status,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
