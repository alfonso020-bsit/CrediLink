import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'barcode_scanner_screen.dart' if (dart.library.html) 'barcode_scanner_screen_web.dart';

/// Opens a barcode scanner on mobile or a manual entry dialog on web.
class BarcodeScannerButton extends StatelessWidget {
  const BarcodeScannerButton({
    super.key,
    required this.onScanned,
    this.label = 'Scan',
    this.icon = Icons.qr_code_scanner,
  });

  final ValueChanged<String> onScanned;
  final String label;
  final IconData icon;

  Future<void> _handlePress(BuildContext context) async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty) {
      onScanned(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: kIsWeb ? 'Enter barcode manually' : label,
      icon: Icon(icon),
      onPressed: () => _handlePress(context),
    );
  }
}

/// Outlined button variant for forms and toolbars.
class BarcodeScannerOutlinedButton extends StatelessWidget {
  const BarcodeScannerOutlinedButton({
    super.key,
    required this.onScanned,
    this.label = 'Scan Barcode',
  });

  final ValueChanged<String> onScanned;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final code = await scanBarcode(context);
        if (code != null && code.isNotEmpty) {
          onScanned(code);
        }
      },
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(kIsWeb ? 'Enter Barcode' : label),
    );
  }
}
