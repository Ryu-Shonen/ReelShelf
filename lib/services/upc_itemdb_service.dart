import 'dart:convert';

import 'package:http/http.dart' as http;

class UpcItemDbException implements Exception {
  const UpcItemDbException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpcItem {
  const UpcItem({
    required this.ean,
    required this.title,
    this.upc,
    this.brand = '',
    this.model = '',
    this.description = '',
    this.category = '',
    this.images = const [],
  });

  final String ean;
  final String title;
  final String? upc;
  final String brand;
  final String model;
  final String description;
  final String category;
  final List<String> images;

  String? get primaryImage => images.isEmpty ? null : images.first;

  bool get isLikelyBoxSet {
    final value = '$title $category'.toLowerCase();
    const markers = [
      'collection',
      'box set',
      'boxset',
      'boxed set',
      'complete series',
      'complete collection',
      'gesamtausgabe',
      'komplettbox',
      'komplett-box',
      'film collection',
      'movie collection',
    ];
    return markers.any(value.contains);
  }

  String get suggestedMediaFormat {
    final value = '$title $category'.toLowerCase();

    if (isLikelyBoxSet) return 'Boxset';
    if (value.contains('steelbook') || value.contains('steel book')) {
      return 'Steelbook';
    }
    if (value.contains('mediabook') || value.contains('media book')) {
      return 'Mediabook';
    }
    if (value.contains('4k') ||
        value.contains('ultra hd') ||
        value.contains('uhd')) {
      return '4K UHD';
    }
    if (value.contains('blu-ray') ||
        value.contains('bluray') ||
        value.contains('blu ray')) {
      return 'Blu-ray';
    }
    if (value.contains('dvd')) return 'DVD';
    return 'Blu-ray';
  }

  String get suggestedMovieQuery {
    var value = title;

    const removable = [
      '4K Ultra HD',
      '4K UHD',
      'Ultra HD',
      'UHD',
      'Blu-ray',
      'Blu Ray',
      'Bluray',
      'DVD',
      'Steelbook',
      'Steel Book',
      'Mediabook',
      'Media Book',
      'Digital HD',
      'Digital Copy',
      'Digital',
    ];

    for (final word in removable) {
      value = value.replaceAll(
        RegExp(RegExp.escape(word), caseSensitive: false),
        ' ',
      );
    }

    value = value
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–—:|]+|[\s\-–—:|]+$'), '')
        .trim();

    return value.isEmpty ? title : value;
  }

  String editionForMovie(String movieTitle) {
    final physicalTitle = title.trim();
    if (physicalTitle.isEmpty) return '';

    final a = physicalTitle.toLowerCase();
    final b = movieTitle.trim().toLowerCase();

    if (a == b) return '';
    return physicalTitle;
  }

  factory UpcItem.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>? ?? const [];

    return UpcItem(
      ean: (json['ean'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      upc: (json['upc'] as String?)?.trim(),
      brand: (json['brand'] as String? ?? '').trim(),
      model: (json['model'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      category: (json['category'] as String? ?? '').trim(),
      images: rawImages
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }
}

class UpcItemDbService {
  const UpcItemDbService();

  static const _host = 'api.upcitemdb.com';
  static const _lookupPath = '/prod/trial/lookup';
  static const _searchPath = '/prod/trial/search';

  static const _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<UpcItem?> lookup(String barcode) async {
    final value = barcode.trim();
    if (value.isEmpty) return null;

    final uri = Uri.https(_host, _lookupPath, {'upc': value});
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 404) return null;
    _throwForError(response);

    final items = _parseItems(response.body);
    return items.isEmpty ? null : items.first;
  }

  Future<List<UpcItem>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];

    final uri = Uri.https(
      _host,
      _searchPath,
      {
        's': value,
        'offset': '0',
      },
    );
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 404) return const [];
    _throwForError(response);

    return _parseItems(response.body);
  }

  List<UpcItem> _parseItems(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const UpcItemDbException(
        'Die Antwort der Ausgabendatenbank konnte nicht gelesen werden.',
      );
    }

    final rawItems = decoded['items'] as List<dynamic>? ?? const [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(UpcItem.fromJson)
        .where((item) => item.title.isNotEmpty)
        .toList();
  }

  void _throwForError(http.Response response) {
    if (response.statusCode == 200) return;

    if (response.statusCode == 429) {
      throw const UpcItemDbException(
        'Das kostenlose Tages- oder Geschwindigkeitslimit von UPCitemdb ist gerade erreicht. Bitte später erneut versuchen.',
      );
    }

    String? apiMessage;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        apiMessage = decoded['message'] as String?;
      }
    } catch (_) {
      // Bei Gateway-Fehlern kann die API statt JSON auch HTML liefern.
    }

    throw UpcItemDbException(
      apiMessage?.trim().isNotEmpty == true
          ? 'UPCitemdb: $apiMessage'
          : 'Ausgabensuche fehlgeschlagen (${response.statusCode}).',
    );
  }
}
