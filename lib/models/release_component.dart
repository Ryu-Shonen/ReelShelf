import 'tmdb_movie.dart';

class ReleaseComponent {
  const ReleaseComponent({
    this.id,
    required this.releaseId,
    this.tmdbId,
    required this.title,
    this.year,
    this.posterPath,
    required this.sequenceNumber,
  });

  final int? id;
  final int releaseId;
  final int? tmdbId;
  final String title;
  final int? year;
  final String? posterPath;
  final int sequenceNumber;

  String? get posterUrl => posterPath == null || posterPath!.isEmpty
      ? null
      : 'https://image.tmdb.org/t/p/w342$posterPath';

  ReleaseComponent copyWith({
    int? id,
    int? releaseId,
    int? tmdbId,
    String? title,
    int? year,
    String? posterPath,
    int? sequenceNumber,
  }) {
    return ReleaseComponent(
      id: id ?? this.id,
      releaseId: releaseId ?? this.releaseId,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      year: year ?? this.year,
      posterPath: posterPath ?? this.posterPath,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  factory ReleaseComponent.fromTmdbMovie(
    TmdbMovie movie, {
    required int releaseId,
    required int sequenceNumber,
  }) {
    return ReleaseComponent(
      releaseId: releaseId,
      tmdbId: movie.id,
      title: movie.title,
      year: movie.year,
      posterPath: movie.posterPath,
      sequenceNumber: sequenceNumber,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'release_id': releaseId,
      'tmdb_id': tmdbId,
      'title': title,
      'year': year,
      'poster_path': posterPath,
      'sequence_number': sequenceNumber,
    };
  }

  factory ReleaseComponent.fromDbMap(Map<String, Object?> map) {
    return ReleaseComponent(
      id: map['id'] as int?,
      releaseId: (map['release_id'] as num).toInt(),
      tmdbId: map['tmdb_id'] as int?,
      title: (map['title'] as String?) ?? '',
      year: map['year'] as int?,
      posterPath: map['poster_path'] as String?,
      sequenceNumber: (map['sequence_number'] as int?) ?? 0,
    );
  }
}
