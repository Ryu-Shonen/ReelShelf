import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _handled = true;
        _controller.stop();
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Barcode scannen'),
        actions: [
          IconButton(
            tooltip: 'Taschenlampe',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            tooltip: 'Kamera wechseln',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: CustomPaint(painter: _ScannerOverlayPainter()),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Halte den EAN-Barcode auf der Filmhülle in den Rahmen. ReelShelf übernimmt die Nummer automatisch.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.78;
    final frameHeight = 150.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: frameWidth,
      height: frameHeight,
    );
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.48);
    final full = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(22)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cutout),
      overlay,
    );

    final border = Paint()
      ..color = const Color(0xFFFF6B7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
