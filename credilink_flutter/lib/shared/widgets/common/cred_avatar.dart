import 'package:flutter/material.dart';

class CredAvatar extends StatelessWidget {
  const CredAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.radius,
    this.imageUrl,
  });

  final String name;
  final double size;
  final double? radius;
  final String? imageUrl;

  double get _radius => radius ?? size / 2;

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _color {
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return Colors.primaries[hash % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: _radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: _radius,
      backgroundColor: _color,
      child: Text(
        _initials,
        style: TextStyle(color: Colors.white, fontSize: _radius * 0.7),
      ),
    );
  }
}
