import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../models/bulk_option.dart';
import '../../../models/product.dart';
import '../../../services/barcode_lookup_service.dart';
import '../auth/cred_text_field.dart';
import '../layout/cred_modal.dart';

class ProductFormData {
  const ProductFormData({
    required this.name,
    required this.barcode,
    required this.category,
    required this.sellingPrice,
    required this.stockQuantity,
    this.description = '',
    this.brand = '',
    this.costPrice = 0,
    this.minStockLevel = 0,
    this.maxStockLevel = 0,
    this.bulkOptions = const [],
    this.hasBarcode = true,
    this.customProductId,
    this.unitOfMeasure = 'piece',
    this.bulkUnit,
    this.piecesPerBulk,
    this.bulkSellingPrice,
    this.imageUrl,
    this.enableBulkPricing = false,
  });

  final String name;
  final String barcode;
  final String category;
  final double sellingPrice;
  final int stockQuantity;
  final String description;
  final String brand;
  final double costPrice;
  final int minStockLevel;
  final int maxStockLevel;
  final List<BulkOption> bulkOptions;
  final bool hasBarcode;
  final String? customProductId;
  final String unitOfMeasure;
  final String? bulkUnit;
  final int? piecesPerBulk;
  final double? bulkSellingPrice;
  final String? imageUrl;
  final bool enableBulkPricing;
}

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({
    super.key,
    this.product,
    required this.onSave,
    this.title = 'Add Product',
    this.initialImageUrl,
    this.initialBarcode,
    this.prefill,
    this.onBarcodeLookup,
  });

  final Product? product;
  final Future<void> Function(ProductFormData data) onSave;
  final String title;
  final String? initialImageUrl;
  final String? initialBarcode;
  final ExternalProductInfo? prefill;
  final Future<BarcodeLookupResult> Function(String barcode)? onBarcodeLookup;

  static Future<ProductFormData?> show(
    BuildContext context, {
    Product? product,
    required Future<void> Function(ProductFormData data) onSave,
    String title = 'Add Product',
    String? initialImageUrl,
    String? initialBarcode,
    ExternalProductInfo? prefill,
    Future<BarcodeLookupResult> Function(String barcode)? onBarcodeLookup,
  }) {
    return showCredModal<ProductFormData>(
      context: context,
      builder: (_) => ProductFormSheet(
        product: product,
        onSave: onSave,
        title: title,
        initialImageUrl: initialImageUrl ?? prefill?.imageUrl,
        initialBarcode: initialBarcode,
        prefill: prefill,
        onBarcodeLookup: onBarcodeLookup,
      ),
    );
  }

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _customIdController;
  late final TextEditingController _categoryController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _brandController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _bulkUnitController;
  late final TextEditingController _piecesPerBulkController;
  late final TextEditingController _bulkPriceController;
  late bool _hasBarcode;
  late bool _enableBulkPricing;
  late bool _enableAdvancedBulk;
  late String _unitOfMeasure;
  List<BulkOption> _bulkOptions = [];
  bool _loading = false;
  bool _lookingUp = false;
  String? _lookupMessage;

  static const _units = ['piece', 'pack', 'box', 'kg', 'g', 'liter', 'ml', 'bottle', 'can'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final prefill = widget.prefill;
    _hasBarcode = p?.hasBarcode ?? true;
    _enableBulkPricing = p != null &&
        (p.bulkOptions.isNotEmpty || p.bulkSellingPrice != null || p.piecesPerBulk != null);
    _enableAdvancedBulk = p != null && p.bulkOptions.isNotEmpty;
    _unitOfMeasure = p?.unitOfMeasure ?? 'piece';
    _bulkOptions = List.of(p?.bulkOptions ?? const []);
    _nameController = TextEditingController(text: p?.name ?? prefill?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _customIdController = TextEditingController(text: p?.customProductId ?? '');
    _categoryController = TextEditingController(text: p?.category ?? prefill?.category ?? '');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice.toString() ?? '');
    _costPriceController = TextEditingController(text: p?.costPrice.toString() ?? '0');
    _stockController = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _minStockController = TextEditingController(text: p?.minStockLevel.toString() ?? '0');
    _maxStockController = TextEditingController(text: p?.maxStockLevel.toString() ?? '0');
    _descriptionController = TextEditingController(text: p?.description ?? prefill?.description ?? '');
    _brandController = TextEditingController(text: p?.brand ?? prefill?.brand ?? '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? widget.initialImageUrl ?? prefill?.imageUrl ?? '');
    _bulkUnitController = TextEditingController(text: p?.bulkUnit ?? '');
    _piecesPerBulkController = TextEditingController(text: p?.piecesPerBulk?.toString() ?? '');
    _bulkPriceController = TextEditingController(text: p?.bulkSellingPrice?.toString() ?? '');
    _imageUrlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _customIdController.dispose();
    _categoryController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    _bulkUnitController.dispose();
    _piecesPerBulkController.dispose();
    _bulkPriceController.dispose();
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('With Barcode')),
                  ButtonSegment(value: false, label: Text('No Barcode')),
                ],
                selected: {_hasBarcode},
                onSelectionChanged: (s) => setState(() {
                  _hasBarcode = s.first;
                  if (!_hasBarcode && _customIdController.text.isEmpty) {
                    _customIdController.text = 'NP-${DateTime.now().millisecondsSinceEpoch}';
                  }
                }),
              ),
              const SizedBox(height: 16),
              _buildImageSection(),
              const SizedBox(height: 16),
              CredTextField(
                controller: _nameController,
                label: 'Product Name',
                icon: Icons.inventory_2_outlined,
                required: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              if (_hasBarcode) ...[
                CredTextField(
                  controller: _barcodeController,
                  label: 'Barcode',
                  icon: Icons.qr_code,
                  onFieldSubmitted: (_) => _lookupBarcode(),
                  suffix: _lookingUp
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(icon: const Icon(Icons.search), onPressed: _lookupBarcode),
                ),
                if (_lookupMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_lookupMessage!, style: const TextStyle(fontSize: 12, color: CredTheme.primary)),
                  ),
              ] else
                CredTextField(
                  controller: _customIdController,
                  label: 'Custom Product ID',
                  icon: Icons.tag,
                  required: true,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Custom ID is required' : null,
                ),
              const SizedBox(height: 16),
              CredTextField(
                controller: _categoryController,
                label: 'Category',
                icon: Icons.category_outlined,
                required: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Category is required' : null,
              ),
              const SizedBox(height: 16),
              CredTextField(controller: _brandController, label: 'Brand', icon: Icons.branding_watermark_outlined),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _unitOfMeasure,
                decoration: const InputDecoration(labelText: 'Unit of Measure'),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _unitOfMeasure = v ?? 'piece'),
              ),
              const SizedBox(height: 16),
              CredTextField(
                controller: _sellingPriceController,
                label: 'Selling Price',
                icon: Icons.sell_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                required: true,
                validator: (v) => _validateNumber(v, 'Selling price'),
              ),
              const SizedBox(height: 16),
              CredTextField(
                controller: _costPriceController,
                label: 'Cost Price',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              CredTextField(
                controller: _stockController,
                label: 'Stock Quantity',
                icon: Icons.warehouse_outlined,
                keyboardType: TextInputType.number,
                required: true,
                validator: (v) => _validateInt(v, 'Stock'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CredTextField(
                      controller: _minStockController,
                      label: 'Min Stock',
                      icon: Icons.warning_amber_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CredTextField(
                      controller: _maxStockController,
                      label: 'Max Stock',
                      icon: Icons.storage_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Bulk Pricing'),
                value: _enableBulkPricing,
                onChanged: (v) => setState(() => _enableBulkPricing = v),
              ),
              if (_enableBulkPricing) ...[
                SwitchListTile(
                  title: const Text('Advanced Bulk Options'),
                  value: _enableAdvancedBulk,
                  onChanged: (v) => setState(() => _enableAdvancedBulk = v),
                ),
                if (!_enableAdvancedBulk) ...[
                  CredTextField(controller: _bulkUnitController, label: 'Bulk Unit', icon: Icons.layers_outlined),
                  const SizedBox(height: 16),
                  CredTextField(
                    controller: _piecesPerBulkController,
                    label: 'Pieces per Bulk',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  CredTextField(
                    controller: _bulkPriceController,
                    label: 'Bulk Selling Price',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ] else ...[
                  ..._bulkOptions.asMap().entries.map((e) => _BulkOptionRow(
                        option: e.value,
                        onChanged: (opt) => setState(() => _bulkOptions[e.key] = opt),
                        onRemove: () => setState(() => _bulkOptions.removeAt(e.key)),
                      )),
                  TextButton.icon(
                    onPressed: () => setState(() => _bulkOptions.add(const BulkOption(label: 'bulk', piecesPerBulk: 1, price: 0))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bulk Option'),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              CredTextField(controller: _descriptionController, label: 'Description', icon: Icons.notes_outlined),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final url = _imageUrlController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url.isNotEmpty)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImagePreview(url),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CredTextField(
          controller: _imageUrlController,
          label: 'Image URL',
          icon: Icons.link,
        ),
      ],
    );
  }

  Widget _buildImagePreview(String url) {
    if (url.startsWith('http')) {
      return Image.network(url, height: 80, width: 80, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80));
    }
    if (!kIsWeb && File(url).existsSync()) {
      return Image.file(File(url), height: 80, width: 80, fit: BoxFit.cover);
    }
    return const Icon(Icons.image, size: 80);
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (file != null) {
      setState(() => _imageUrlController.text = file.path);
    }
  }

  Future<void> _lookupBarcode() async {
    if (widget.onBarcodeLookup == null) return;
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
    });
    try {
      final result = await widget.onBarcodeLookup!(barcode);
      if (!mounted) return;
      if (result.success && result.product != null) {
        final info = result.product!;
        if (_nameController.text.isEmpty) _nameController.text = info.name;
        if (_brandController.text.isEmpty) _brandController.text = info.brand;
        if (_categoryController.text.isEmpty) _categoryController.text = info.category;
        if (_descriptionController.text.isEmpty) _descriptionController.text = info.description;
        if (_imageUrlController.text.isEmpty && info.imageUrl.isNotEmpty) {
          _imageUrlController.text = info.imageUrl;
        }
        _lookupMessage = result.message;
      } else {
        _lookupMessage = result.message;
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  String? _validateNumber(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    return null;
  }

  String? _validateInt(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    if (int.tryParse(v) == null) return 'Enter a valid whole number';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final bulkOptions = _enableBulkPricing && _enableAdvancedBulk ? _bulkOptions : <BulkOption>[];
    final data = ProductFormData(
      name: _nameController.text.trim(),
      barcode: _hasBarcode ? _barcodeController.text.trim() : '',
      category: _categoryController.text.trim(),
      sellingPrice: double.parse(_sellingPriceController.text),
      stockQuantity: int.parse(_stockController.text),
      description: _descriptionController.text.trim(),
      brand: _brandController.text.trim(),
      costPrice: double.tryParse(_costPriceController.text) ?? 0,
      minStockLevel: int.tryParse(_minStockController.text) ?? 0,
      maxStockLevel: int.tryParse(_maxStockController.text) ?? 0,
      bulkOptions: bulkOptions,
      hasBarcode: _hasBarcode,
      customProductId: _hasBarcode ? null : _customIdController.text.trim(),
      unitOfMeasure: _unitOfMeasure,
      bulkUnit: _enableBulkPricing && !_enableAdvancedBulk ? _bulkUnitController.text.trim() : null,
      piecesPerBulk: _enableBulkPricing && !_enableAdvancedBulk ? int.tryParse(_piecesPerBulkController.text) : null,
      bulkSellingPrice: _enableBulkPricing && !_enableAdvancedBulk ? double.tryParse(_bulkPriceController.text) : null,
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      enableBulkPricing: _enableBulkPricing,
    );

    try {
      await widget.onSave(data);
      if (context.mounted) Navigator.pop(context, data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BulkOptionRow extends StatefulWidget {
  const _BulkOptionRow({required this.option, required this.onChanged, required this.onRemove});

  final BulkOption option;
  final ValueChanged<BulkOption> onChanged;
  final VoidCallback onRemove;

  @override
  State<_BulkOptionRow> createState() => _BulkOptionRowState();
}

class _BulkOptionRowState extends State<_BulkOptionRow> {
  late final TextEditingController _label;
  late final TextEditingController _pieces;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.option.label);
    _pieces = TextEditingController(text: widget.option.piecesPerBulk.toString());
    _price = TextEditingController(text: widget.option.price.toString());
  }

  @override
  void dispose() {
    _label.dispose();
    _pieces.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label', isDense: true))),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: widget.onRemove),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pieces,
                    decoration: const InputDecoration(labelText: 'Pieces', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Price', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _emit() {
    widget.onChanged(BulkOption(
      label: _label.text.trim().isEmpty ? 'bulk' : _label.text.trim(),
      piecesPerBulk: int.tryParse(_pieces.text) ?? 1,
      price: double.tryParse(_price.text) ?? 0,
    ));
  }
}
