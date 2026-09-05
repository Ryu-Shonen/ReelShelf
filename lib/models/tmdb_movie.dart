import 'collection_item.dart';

class TmdbMovie {
  const TmdbMovie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.releaseDate,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.runtime,
    this.genres = const [],
    this.voteAverage,
    this.originalLanguage,
  });

  final int id;
  final String title;
  final String? originalTitle;
  final String? releaseDate;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final int? runtime;
  final List<String> genres;
  final double? voteAverage;
  final String? originalLanguage;

  int? get year {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return int.tryParse(releaseDate!.substring(0, 4));
  }

  String? get posterUrl => posterPath == null || posterPath!.isEmpty
      ? null
      : 'https://image.tmdb.org/t/p/w342$posterPath';

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
            .whereType<Map>()
            .map((e) => e['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return TmdbMovie(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? json['name'] ?? 'Unbekannter Film').toString(),
      originalTitle: json['original_title']?.toString(),
      releaseDate: json['release_date']?.toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      overview: json['overview']?.toString(),
      runtime: (json['runtime'] as num?)?.toInt(),
      genres: genres,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      originalLanguage: json['original_language']?.toString(),
    );
  }

  CollectionItem toCollectionItem({String ean = ''}) {
    final now = DateTime.now();
    return CollectionItem(
      tmdbId: id,
      title: title,
      originalTitle: originalTitle,
      year: year,
      releaseDate: releaseDate,
      posterPath: posterPath,
      backdropPath: backdropPath,
      overview: overview,
      runtime: runtime,
      genres: genres.join(', '),
      voteAverage: voteAverage,
      originalLanguage: originalLanguage,
      ean: ean,
      createdAt: now,
      updatedAt: now,
    );
  }
}
