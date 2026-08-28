import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ph_address.dart';
import '../../../repositories/repositories.dart';

class PhAddressPicker extends ConsumerStatefulWidget {
  const PhAddressPicker({
    super.key,
    required this.onChanged,
    this.initial,
    this.sitioController,
  });

  final ValueChanged<PhAddress> onChanged;
  final PhAddress? initial;
  final TextEditingController? sitioController;

  @override
  ConsumerState<PhAddressPicker> createState() => _PhAddressPickerState();
}

class _PhAddressPickerState extends ConsumerState<PhAddressPicker> {
  String? _regionCode;
  String? _regionName;
  String? _province;
  String? _municipality;
  String? _barangay;

  List<PhRegion> _regions = [];
  List<String> _provinces = [];
  List<String> _municipalities = [];
  List<String> _barangays = [];

  @override
  void initState() {
    super.initState();
    _loadRegions();
    if (widget.initial != null) {
      _province = widget.initial!.province;
      _municipality = widget.initial!.municipality;
      _barangay = widget.initial!.barangay;
    }
  }

  Future<void> _loadRegions() async {
    final regions = await ref.read(locationRepositoryProvider).getRegions();
    if (mounted) setState(() => _regions = regions);
  }

  void _notify() {
    if (_province == null || _municipality == null || _barangay == null) return;
    widget.onChanged(PhAddress(
      region: _regionName,
      province: _province!,
      municipality: _municipality!,
      barangay: _barangay!,
      sitioPurok: widget.sitioController?.text,
    ));
  }

  PhRegion? get _selectedRegion {
    for (final r in _regions) {
      if (r.code == _regionCode) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _dropdown<PhRegion>(
          label: 'Region',
          value: _selectedRegion,
          items: _regions,
          itemLabel: (r) => r.name,
          onChanged: (r) async {
            setState(() {
              _regionCode = r?.code;
              _regionName = r?.name;
              _province = _municipality = _barangay = null;
              _provinces = _municipalities = _barangays = [];
            });
            if (r != null) {
              final p = await ref.read(locationRepositoryProvider).getProvinces(r.code);
              if (mounted) setState(() => _provinces = p);
            }
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _dropdown<String>(
          label: 'Province',
          value: _province,
          items: _provinces,
          itemLabel: (s) => s,
          onChanged: (p) async {
            setState(() {
              _province = p;
              _municipality = _barangay = null;
              _municipalities = _barangays = [];
            });
            if (p != null && _regionCode != null) {
              final m = await ref
                  .read(locationRepositoryProvider)
                  .getMunicipalities(_regionCode!, p);
              if (mounted) setState(() => _municipalities = m);
            }
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _dropdown<String>(
          label: 'Municipality / City',
          value: _municipality,
          items: _municipalities,
          itemLabel: (s) => s,
          onChanged: (m) async {
            setState(() {
              _municipality = m;
              _barangay = null;
              _barangays = [];
            });
            if (m != null && _regionCode != null && _province != null) {
              final b = await ref.read(locationRepositoryProvider).getBarangays(
                    _regionCode!,
                    _province!,
                    m,
                  );
              if (mounted) setState(() => _barangays = b);
            }
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _dropdown<String>(
          label: 'Barangay',
          value: _barangay,
          items: _barangays,
          itemLabel: (s) => s,
          onChanged: (b) {
            setState(() => _barangay = b);
            _notify();
          },
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      value: items.contains(value) ? value : null,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
