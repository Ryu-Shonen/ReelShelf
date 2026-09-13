class ImdbRating {
  const ImdbRating({
    required this.tmdbId,
    required this.imdbId,
    this.rating,
    this.voteCount,
    required this.updatedAt,
  });

  final int tmdbId;
  final String imdbId;
  final double? rating;
  final int? voteCount;
  final DateTime updatedAt;

  bool get hasRating => rating != null;

  bool isFresh([Duration maxAge = const Duration(days: 7)]) {
    return DateTime.now().difference(updatedAt) < maxAge;
  }

  Map<String, Object?> toDbMap() {
    return {
      'tmdb_id': tmdbId,
      'imdb_id': imdbId,
      'rating': rating,
      'vote_count': voteCount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ImdbRating.fromDbMap(Map<String, Object?> map) {
    return ImdbRating(
      tmdbId: (map['tmdb_id'] as num).toInt(),
      imdbId: (map['imdb_id'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toDouble(),
      voteCount: (map['vote_count'] as num?)?.toInt(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
