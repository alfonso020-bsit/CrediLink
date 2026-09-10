import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../auth/cred_text_field.dart';
import '../layout/cred_modal.dart';

enum StockAdjustType { add, remove, set }

class StockAdjustResult {
  const StockAdjustResult({
    required this.type,
    required this.quantity,
    this.reason,
  });

  final StockAdjustType type;
  final int quantity;
  final String? reason;
}

class StockAdjustSheet extends StatefulWidget {
  const StockAdjustSheet({
    super.key,
    required this.product,
    required this.onAdjust,
  });

  final Product product;
  final Future<void> Function(StockAdjustResult result) onAdjust;

  static Future<StockAdjustResult?> show(
    BuildContext context, {
    required Product product,
    required Future<void> Function(StockAdjustResult result) onAdjust,
  }) {
    return showCredModal<StockAdjustResult>(
      context: context,
      builder: (_) => StockAdjustSheet(product: product, onAdjust: onAdjust),
    );
  }

  @override
  State<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends State<StockAdjustSheet> {
  StockAdjustType _type = StockAdjustType.add;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Adjust Stock', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${widget.product.name} — current: ${widget.product.stockQuantity}'),
          const SizedBox(height: 20),
          SegmentedButton<StockAdjustType>(
            segments: const [
              ButtonSegment(value: StockAdjustType.add, label: Text('Add')),
              ButtonSegment(value: StockAdjustType.remove, label: Text('Remove')),
              ButtonSegment(value: StockAdjustType.set, label: Text('Set')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          CredTextField(
            controller: _quantityController,
            label: 'Quantity',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
            required: true,
          ),
          const SizedBox(height: 16),
          CredTextField(
            controller: _reasonController,
            label: 'Reason (optional)',
            icon: Icons.notes_outlined,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Apply Adjustment'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_quantityController.text);
    if (qty == null || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    setState(() => _loading = true);
    final result = StockAdjustResult(
      type: _type,
      quantity: qty,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
    );
    try {
      await widget.onAdjust(result);
      if (context.mounted) Navigator.pop(context, result);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
