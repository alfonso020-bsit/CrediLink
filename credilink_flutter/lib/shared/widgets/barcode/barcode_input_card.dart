import 'package:flutter/material.dart';

class BarcodeInputCard extends StatelessWidget {
  const BarcodeInputCard({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onScan,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Scan or enter barcode',
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            if (onScan != null)
              IconButton(
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            IconButton(onPressed: onSubmit, icon: const Icon(Icons.search)),
          ],
        ),
      ),
    );
  }
}
