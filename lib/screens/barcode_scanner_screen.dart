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
    cameraResolution: const Size(1920, 1080),
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 150,
    autoZoom: true,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.itf,
    ],
  );

  String? _detectedCode;
  BarcodeFormat? _detectedFormat;
  String? _cameraError;
  bool _processingDetection = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processingDetection || _detectedCode != null) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;

      _processingDetection = true;
      await HapticFeedback.mediumImpact();
      await _controller.pause();

      if (!mounted) return;

      setState(() {
        _detectedCode = code;
        _detectedFormat = barcode.format;
        _cameraError = null;
        _processingDetection = false;
      });
      return;
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _detectedCode = null;
      _detectedFormat = null;
      _cameraError = null;
      _processingDetection = false;
    });
    await _controller.start();
  }

  void _acceptDetected() {
    final code = _detectedCode?.trim();
    if (code == null || code.isEmpty) return;
    Navigator.of(context).pop(code);
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

  String _formatLabel(BarcodeFormat? format) {
    return switch (format) {
      BarcodeFormat.ean13 => 'EAN-13',
      BarcodeFormat.ean8 => 'EAN-8',
      BarcodeFormat.upcA => 'UPC-A',
      BarcodeFormat.upcE => 'UPC-E',
      BarcodeFormat.code128 => 'Code 128',
      BarcodeFormat.itf => 'ITF',
      _ => 'Barcode',
    };
  }

  @override
  Widget build(BuildContext context) {
    final detected = _detectedCode != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Barcode scannen'),
        actions: [
          IconButton(
            tooltip: 'Taschenlampe',
            onPressed: detected ? null : _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            tooltip: 'Kamera wechseln',
            onPressed: detected ? null : _controller.switchCamera,
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
            onDetectError: (error, _) {
              if (!mounted) return;
              setState(() => _cameraError = error.toString());
            },
          ),
          IgnorePointer(
            child: CustomPaint(painter: _ScannerOverlayPainter()),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: detected
                    ? _DetectedCard(
                        key: const ValueKey('detected'),
                        code: _detectedCode!,
                        format: _formatLabel(_detectedFormat),
                        onAccept: _acceptDetected,
                        onRetry: _scanAgain,
                      )
                    : _ScanHelpCard(
                        key: const ValueKey('scanning'),
                        error: _cameraError,
                        onManual: _enterManually,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedCard extends StatelessWidget {
  const _DetectedCard({
    super.key,
    required this.code,
    required this.format,
    required this.onAccept,
    required this.onRetry,
  });

  final String code;
  final String format;
  final VoidCallback onAccept;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B7A).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFFFF6B7A)),
              SizedBox(width: 8),
              Text(
                'Barcode erkannt',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            format,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Nochmal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Übernehmen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanHelpCard extends StatelessWidget {
  const _ScanHelpCard({
    super.key,
    required this.error,
    required this.onManual,
  });

  final String? error;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Halte nur den Strichcode in den Rahmen. Starte etwa 20–30 cm entfernt und bewege das Handy langsam näher. Tippe auf den Barcode, wenn die Kamera nicht scharfstellt.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4),
          ),
          if (error != null) ...[
            const SizedBox(height: 9),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('EAN stattdessen eingeben'),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.90;
    final frameHeight = 160.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: frameWidth,
      height: frameHeight,
    );

    final overlay = Paint()
      ..color = Colors.black.withValues(alpha: 0.42);

    final full = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(20),
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
        const Radius.circular(20),
      ),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
