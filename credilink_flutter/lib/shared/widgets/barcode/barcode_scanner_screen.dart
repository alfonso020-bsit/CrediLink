import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/cred_theme.dart';

Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _MobileBarcodeScannerPage()),
  );
}

class _MobileBarcodeScannerPage extends StatefulWidget {
  const _MobileBarcodeScannerPage();

  @override
  State<_MobileBarcodeScannerPage> createState() => _MobileBarcodeScannerPageState();
}

class _MobileBarcodeScannerPageState extends State<_MobileBarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _torchOn = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torch not available on this device')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Torch off' : 'Torch on',
            onPressed: _toggleTorch,
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: _permissionError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(CredTheme.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white70),
                    const SizedBox(height: CredTheme.spaceMd),
                    Text(
                      _permissionError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: CredTheme.spaceMd),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _permissionError = error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission denied. Enable camera access in settings to scan barcodes.'
                            : 'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}';
                      });
                    });
                    return const SizedBox.shrink();
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ViewfinderPainter(color: CredTheme.primary),
                    child: const SizedBox.expand(),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(CredTheme.spaceLg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CredTheme.spaceMd,
                          vertical: CredTheme.spaceSm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(CredTheme.radiusCard),
                        ),
                        child: const Text(
                          'Align the barcode inside the frame',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final holeSize = Size(size.width * 0.72, size.width * 0.42);
    final left = (size.width - holeSize.width) / 2;
    final top = (size.height - holeSize.height) / 2;
    final hole = Rect.fromLTWH(left, top, holeSize.width, holeSize.height);

    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.45));

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    // Top-left
    canvas.drawLine(Offset(hole.left, hole.top + len), Offset(hole.left, hole.top), cornerPaint);
    canvas.drawLine(Offset(hole.left, hole.top), Offset(hole.left + len, hole.top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(hole.right - len, hole.top), Offset(hole.right, hole.top), cornerPaint);
    canvas.drawLine(Offset(hole.right, hole.top), Offset(hole.right, hole.top + len), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(hole.left, hole.bottom - len), Offset(hole.left, hole.bottom), cornerPaint);
    canvas.drawLine(Offset(hole.left, hole.bottom), Offset(hole.left + len, hole.bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(hole.right - len, hole.bottom), Offset(hole.right, hole.bottom), cornerPaint);
    canvas.drawLine(Offset(hole.right, hole.bottom), Offset(hole.right, hole.bottom - len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) => oldDelegate.color != color;
}
