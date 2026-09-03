import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cred_theme.dart';
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
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final regions = await ref.read(locationRepositoryProvider).getRegions();
    if (!mounted) return;
    setState(() => _regions = regions);
    await _hydrateFromInitial(widget.initial);
  }

  String? _matchName(List<String> items, String? needle) {
    final target = needle?.trim();
    if (target == null || target.isEmpty) return null;
    for (final item in items) {
      if (item.toLowerCase() == target.toLowerCase()) return item;
    }
    return null;
  }

  PhRegion? _matchRegion(String? needle) {
    final target = needle?.trim();
    if (target == null || target.isEmpty) return null;
    for (final r in _regions) {
      if (r.name.toLowerCase() == target.toLowerCase() || r.code == target) {
        return r;
      }
    }
    return null;
  }

  Future<void> _hydrateFromInitial(PhAddress? initial) async {
    if (initial == null || _hydrating) return;
    final hasAddress = initial.province.trim().isNotEmpty ||
        initial.municipality.trim().isNotEmpty ||
        initial.barangay.trim().isNotEmpty;
    if (!hasAddress && (initial.region == null || initial.region!.trim().isEmpty)) {
      return;
    }

    _hydrating = true;
    final location = ref.read(locationRepositoryProvider);

    try {
      var region = _matchRegion(initial.region);

      // If region missing/mismatched, find which region contains the province.
      if (region == null && initial.province.trim().isNotEmpty) {
        for (final candidate in _regions) {
          final provinces = await location.getProvinces(candidate.code);
          final matched = _matchName(provinces, initial.province);
          if (matched != null) {
            region = candidate;
            _provinces = provinces;
            _province = matched;
            break;
          }
        }
      }

      if (region == null) return;

      _regionCode = region.code;
      _regionName = region.name;

      if (_provinces.isEmpty) {
        _provinces = await location.getProvinces(region.code);
      }
      _province ??= _matchName(_provinces, initial.province);

      if (_province != null) {
        _municipalities = await location.getMunicipalities(region.code, _province!);
        _municipality = _matchName(_municipalities, initial.municipality);

        if (_municipality != null) {
          _barangays = await location.getBarangays(
            region.code,
            _province!,
            _municipality!,
          );
          _barangay = _matchName(_barangays, initial.barangay);
        }
      }

      if (mounted) setState(() {});
      _notify();
    } finally {
      _hydrating = false;
    }
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
        const SizedBox(height: CredTheme.spaceSm),
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
        const SizedBox(height: CredTheme.spaceSm),
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
        const SizedBox(height: CredTheme.spaceSm),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CredTheme.titleText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: CredTheme.inputBackground,
            borderRadius: BorderRadius.circular(CredTheme.radiusInput),
            border: Border.all(color: CredTheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              icon: const Icon(Icons.keyboard_arrow_down, color: CredTheme.subtitleText),
              style: const TextStyle(fontSize: 14, color: CredTheme.titleText),
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: const Text(
                'Select',
                style: TextStyle(fontSize: 14, color: CredTheme.placeholder),
              ),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
