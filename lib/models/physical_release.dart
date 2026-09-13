import 'collection_item.dart';

class PhysicalRelease {
  const PhysicalRelease({
    this.id,
    required this.ean,
    this.tmdbId,
    required this.title,
    this.mediaFormat = 'Blu-ray',
    this.edition = '',
    this.releaseType = 'single',
    this.region = 'DE',
    this.packaging = '',
    this.publisher = '',
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String ean;
  final int? tmdbId;
  final String title;
  final String mediaFormat;
  final String edition;
  final String releaseType;
  final String region;
  final String packaging;
  final String publisher;
  final String? coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isBoxSet => releaseType == 'boxset';

  bool get hasScannableEan =>
      ean.isNotEmpty && !ean.startsWith('LOCALBOX-');

  String get displayEan => hasScannableEan ? ean : '';

  static String normalizeBarcode(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
        .toUpperCase();
  }

  PhysicalRelease copyWith({
    int? id,
    String? ean,
    int? tmdbId,
    String? title,
    String? mediaFormat,
    String? edition,
    String? releaseType,
    String? region,
    String? packaging,
    String? publisher,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhysicalRelease(
      id: id ?? this.id,
      ean: ean ?? this.ean,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      mediaFormat: mediaFormat ?? this.mediaFormat,
      edition: edition ?? this.edition,
      releaseType: releaseType ?? this.releaseType,
      region: region ?? this.region,
      packaging: packaging ?? this.packaging,
      publisher: publisher ?? this.publisher,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PhysicalRelease.fromCollectionItem(
    CollectionItem item, {
    String region = 'DE',
    String? storageEan,
  }) {
    final now = DateTime.now();
    return PhysicalRelease(
      id: item.releaseId,
      ean: storageEan ?? normalizeBarcode(item.ean),
      tmdbId: item.tmdbId,
      title: item.title,
      mediaFormat: item.mediaFormat,
      edition: item.edition,
      releaseType: item.mediaFormat == 'Boxset' ? 'boxset' : 'single',
      region: region,
      createdAt: item.createdAt,
      updatedAt: now,
    );
  }

  CollectionItem applyTo(
    CollectionItem item, {
    required bool wishlist,
  }) {
    return item.copyWith(
      releaseId: id,
      tmdbId: tmdbId ?? item.tmdbId,
      title: item.title.trim().isEmpty ? title : item.title,
      ean: displayEan.isNotEmpty ? displayEan : item.ean,
      mediaFormat: mediaFormat,
      edition: edition,
      wishlist: wishlist,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'ean': ean,
      'tmdb_id': tmdbId,
      'title': title,
      'media_format': mediaFormat,
      'edition': edition,
      'release_type': releaseType,
      'region': region,
      'packaging': packaging,
      'publisher': publisher,
      'cover_url': coverUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PhysicalRelease.fromDbMap(Map<String, Object?> map) {
    return PhysicalRelease(
      id: map['id'] as int?,
      ean: (map['ean'] as String?) ?? '',
      tmdbId: map['tmdb_id'] as int?,
      title: (map['title'] as String?) ?? '',
      mediaFormat: (map['media_format'] as String?) ?? 'Blu-ray',
      edition: (map['edition'] as String?) ?? '',
      releaseType: (map['release_type'] as String?) ?? 'single',
      region: (map['region'] as String?) ?? 'DE',
      packaging: (map['packaging'] as String?) ?? '',
      publisher: (map['publisher'] as String?) ?? '',
      coverUrl: map['cover_url'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, Object?> toJson() => toDbMap();

  factory PhysicalRelease.fromJson(Map<String, dynamic> map) {
    final normalized = <String, Object?>{};
    for (final entry in map.entries) {
      normalized[entry.key] = entry.value;
    }
    return PhysicalRelease.fromDbMap(normalized);
  }
}
