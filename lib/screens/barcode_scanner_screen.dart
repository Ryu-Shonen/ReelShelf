import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 250,
    autoZoom: true,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;

      _handled = true;
      await HapticFeedback.mediumImpact();
      await _controller.stop();

      if (!mounted) return;
      Navigator.of(context).pop(code);
      return;
    }
  }

  Future<void> _enterManually() async {
    final textController = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EAN / Barcode eingeben'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'EAN / UPC',
            hintText: 'z. B. 0888750199799',
          ),
          onSubmitted: (value) =>
              Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(textController.text.trim()),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );

    textController.dispose();

    if (!mounted || value == null || value.trim().isEmpty) return;
    Navigator.of(context).pop(value.trim());
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
          MobileScanner(
            controller: _controller,
            tapToFocus: true,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: CustomPaint(painter: _ScannerOverlayPainter()),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Halte den Barcode möglichst gerade in den Rahmen. Tippe bei Bedarf auf den Barcode, damit die Kamera fokussiert.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 11),
                    TextButton.icon(
                      onPressed: _enterManually,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('EAN stattdessen eingeben'),
                    ),
                  ],
                ),
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
    final frameWidth = size.width * 0.88;
    final frameHeight = 180.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: frameWidth,
      height: frameHeight,
    );

    final overlay = Paint()
      ..color = Colors.black.withValues(alpha: 0.44);

    final full = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(22),
        ),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cutout),
      overlay,
    );

    final border = Paint()
      ..color = const Color(0xFFFF6B7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(22),
      ),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
