import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class CoverScanResult {
  const CoverScanResult({
    required this.imagePath,
    required this.rawText,
    required this.detectedLines,
    required this.searchQueries,
  });

  final String imagePath;
  final String rawText;
  final List<String> detectedLines;
  final List<String> searchQueries;

  String get summary {
    if (detectedLines.isEmpty) return 'Kein lesbarer Text erkannt.';
    return detectedLines.take(4).join(' · ');
  }
}

class CoverScanService {
  CoverScanService({
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  static const _technicalTerms = <String>{
    'blu ray',
    'bluray',
    'ultra hd',
    'ultra hd blu ray',
    '4k',
    '4k uhd',
    'uhd',
    'dvd',
    'hdr',
    'hdr10',
    'hdr10+',
    'dolby',
    'dolby atmos',
    'dolby vision',
    'dts',
    'dts hd',
    'digital',
    'steelbook',
    'mediabook',
    'limited edition',
    'special edition',
    'collector edition',
    'collectors edition',
    'fsk',
    'usk',
    'studio canal',
    'studiocanal',
    'universal',
    'warner bros',
    'warner home video',
    'paramount',
    'sony pictures',
    '20th century',
    'walt disney',
    'disney',
    'netflix',
    'amazon',
    'prime video',
  };

  Future<CoverScanResult?> scanCover() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
      maxWidth: 2400,
    );

    if (image == null) return null;

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(inputImage);

      final entries = <_ScoredLine>[];

      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = _cleanLine(line.text);
          if (!_isUsefulLine(text)) continue;

          final score = _scoreLine(
            text,
            line.boundingBox.width,
            line.boundingBox.height,
          );

          entries.add(
            _ScoredLine(
              text: text,
              score: score,
            ),
          );
        }
      }

      entries.sort((a, b) => b.score.compareTo(a.score));

      final rankedLines = <String>[];
      final seenLines = <String>{};

      for (final entry in entries) {
        final key = _normalizeForComparison(entry.text);
        if (key.isEmpty || !seenLines.add(key)) continue;
        rankedLines.add(entry.text);
      }

      final queries = _buildQueries(rankedLines);

      return CoverScanResult(
        imagePath: image.path,
        rawText: recognized.text,
        detectedLines: rankedLines,
        searchQueries: queries,
      );
    } finally {
      await recognizer.close();
    }
  }

  List<String> _buildQueries(List<String> lines) {
    final queries = <String>[];
    final seen = <String>{};

    void add(String value) {
      final cleaned = _cleanLine(value);
      final key = _normalizeForComparison(cleaned);

      if (cleaned.length < 3 || key.isEmpty || !seen.add(key)) {
        return;
      }

      queries.add(cleaned);
    }

    for (final line in lines.take(6)) {
      add(line);
    }

    for (var index = 0; index + 1 < lines.length && index < 5; index++) {
      final combined = '${lines[index]} ${lines[index + 1]}';
      if (combined.length <= 90) add(combined);
    }

    if (lines.length >= 3) {
      final combined =
          '${lines[0]} ${lines[1]} ${lines[2]}';
      if (combined.length <= 100) add(combined);
    }

    return queries.take(8).toList(growable: false);
  }

  bool _isUsefulLine(String text) {
    final normalized = _normalizeForComparison(text);
    if (normalized.length < 3 || normalized.length > 90) {
      return false;
    }

    final letterCount =
        RegExp(r'[A-Za-zÄÖÜäöüß]').allMatches(text).length;
    if (letterCount < 3) return false;

    if (RegExp(r'^\d{1,4}$').hasMatch(normalized)) {
      return false;
    }

    if (_technicalTerms.contains(normalized)) return false;

    final tokens = normalized.split(' ');
    final meaningfulTokens = tokens
        .where((token) => token.length >= 2)
        .toList(growable: false);

    if (meaningfulTokens.isEmpty) return false;

    final technicalTokenCount = meaningfulTokens
        .where(_technicalTerms.contains)
        .length;

    return technicalTokenCount < meaningfulTokens.length;
  }

  double _scoreLine(
    String text,
    double width,
    double height,
  ) {
    final normalized = _normalizeForComparison(text);
    final wordCount = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .length;

    var score = 0.0;

    score += height * 2.2;
    score += width * 0.04;
    score += text.length.clamp(0, 50) * 0.8;

    if (wordCount >= 2 && wordCount <= 7) {
      score += 24;
    } else if (wordCount > 10) {
      score -= 20;
    }

    if (text.length >= 6 && text.length <= 55) {
      score += 16;
    }

    final upper = text
        .split('')
        .where((char) =>
            RegExp(r'[A-ZÄÖÜ]').hasMatch(char))
        .length;
    final letters = text
        .split('')
        .where((char) =>
            RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(char))
        .length;

    if (letters > 0 && upper / letters > 0.55) {
      score += 8;
    }

    return score;
  }

  static String _cleanLine(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[|•·:;,\-–—]+'), '')
        .replaceAll(RegExp(r'[|•·:;,]+$'), '')
        .trim();
  }

  static String _normalizeForComparison(String value) {
    return value
        .toLowerCase()
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ScoredLine {
  const _ScoredLine({
    required this.text,
    required this.score,
  });

  final String text;
  final double score;
}
