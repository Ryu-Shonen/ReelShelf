class CollectionItem {
  const CollectionItem({
    this.id,
    this.tmdbId,
    required this.title,
    this.originalTitle,
    this.year,
    this.releaseDate,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.runtime,
    this.genres = '',
    this.voteAverage,
    this.originalLanguage,
    this.mediaFormat = 'Blu-ray',
    this.edition = '',
    this.ean = '',
    this.purchasePrice,
    this.purchaseDate,
    this.condition = 'Sehr gut',
    this.location = '',
    this.notes = '',
    this.favorite = false,
    this.wishlist = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int? tmdbId;
  final String title;
  final String? originalTitle;
  final int? year;
  final String? releaseDate;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final int? runtime;
  final String genres;
  final double? voteAverage;
  final String? originalLanguage;
  final String mediaFormat;
  final String edition;
  final String ean;
  final double? purchasePrice;
  final String? purchaseDate;
  final String condition;
  final String location;
  final String notes;
  final bool favorite;
  final bool wishlist;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const mediaFormats = <String>[
    '4K UHD',
    'Blu-ray',
    'DVD',
    'Steelbook',
    'Mediabook',
    'Boxset',
    'Sonstiges',
  ];

  static const conditions = <String>[
    'Neu / OVP',
    'Wie neu',
    'Sehr gut',
    'Gut',
    'Akzeptabel',
  ];

  String? get posterUrl => posterPath == null || posterPath!.isEmpty
      ? null
      : 'https://image.tmdb.org/t/p/w500$posterPath';

  String? get backdropUrl => backdropPath == null || backdropPath!.isEmpty
      ? null
      : 'https://image.tmdb.org/t/p/w1280$backdropPath';

  CollectionItem copyWith({
    int? id,
    int? tmdbId,
    String? title,
    String? originalTitle,
    int? year,
    String? releaseDate,
    String? posterPath,
    String? backdropPath,
    String? overview,
    int? runtime,
    String? genres,
    double? voteAverage,
    String? originalLanguage,
    String? mediaFormat,
    String? edition,
    String? ean,
    double? purchasePrice,
    String? purchaseDate,
    String? condition,
    String? location,
    String? notes,
    bool? favorite,
    bool? wishlist,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      year: year ?? this.year,
      releaseDate: releaseDate ?? this.releaseDate,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      overview: overview ?? this.overview,
      runtime: runtime ?? this.runtime,
      genres: genres ?? this.genres,
      voteAverage: voteAverage ?? this.voteAverage,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      mediaFormat: mediaFormat ?? this.mediaFormat,
      edition: edition ?? this.edition,
      ean: ean ?? this.ean,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      condition: condition ?? this.condition,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      wishlist: wishlist ?? this.wishlist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  CollectionItem withoutId() {
    return CollectionItem(
      tmdbId: tmdbId,
      title: title,
      originalTitle: originalTitle,
      year: year,
      releaseDate: releaseDate,
      posterPath: posterPath,
      backdropPath: backdropPath,
      overview: overview,
      runtime: runtime,
      genres: genres,
      voteAverage: voteAverage,
      originalLanguage: originalLanguage,
      mediaFormat: mediaFormat,
      edition: edition,
      ean: ean,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      condition: condition,
      location: location,
      notes: notes,
      favorite: favorite,
      wishlist: wishlist,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'tmdb_id': tmdbId,
      'title': title,
      'original_title': originalTitle,
      'year': year,
      'release_date': releaseDate,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'overview': overview,
      'runtime': runtime,
      'genres': genres,
      'vote_average': voteAverage,
      'original_language': originalLanguage,
      'media_format': mediaFormat,
      'edition': edition,
      'ean': ean,
      'purchase_price': purchasePrice,
      'purchase_date': purchaseDate,
      'condition': condition,
      'location': location,
      'notes': notes,
      'favorite': favorite ? 1 : 0,
      'wishlist': wishlist ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CollectionItem.fromDbMap(Map<String, Object?> map) {
    return CollectionItem(
      id: map['id'] as int?,
      tmdbId: map['tmdb_id'] as int?,
      title: map['title'] as String,
      originalTitle: map['original_title'] as String?,
      year: map['year'] as int?,
      releaseDate: map['release_date'] as String?,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      overview: map['overview'] as String?,
      runtime: map['runtime'] as int?,
      genres: (map['genres'] as String?) ?? '',
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      originalLanguage: map['original_language'] as String?,
      mediaFormat: (map['media_format'] as String?) ?? 'Blu-ray',
      edition: (map['edition'] as String?) ?? '',
      ean: (map['ean'] as String?) ?? '',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
      purchaseDate: map['purchase_date'] as String?,
      condition: (map['condition'] as String?) ?? 'Sehr gut',
      location: (map['location'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      favorite: (map['favorite'] as int? ?? 0) == 1,
      wishlist: (map['wishlist'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, Object?> toJson() => toDbMap();

  factory CollectionItem.fromJson(Map<String, dynamic> map) {
    final normalized = <String, Object?>{};
    for (final entry in map.entries) {
      normalized[entry.key] = entry.value;
    }
    return CollectionItem.fromDbMap(normalized);
  }
}
