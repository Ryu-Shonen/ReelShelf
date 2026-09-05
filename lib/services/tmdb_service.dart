import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tmdb_movie.dart';

class TmdbException implements Exception {
  const TmdbException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TmdbService {
  const TmdbService({
    required this.token,
    this.language = 'de-DE',
    this.region = 'DE',
  });

  final String token;
  final String language;
  final String region;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'accept': 'application/json',
      };

  void _ensureConfigured() {
    if (token.trim().isEmpty) {
      throw const TmdbException(
        'Bitte zuerst in den Einstellungen einen TMDB Read Access Token hinterlegen.',
      );
    }
  }

  Future<List<TmdbMovie>> searchMovies(String query) async {
    _ensureConfigured();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/search/movie',
      {
        'query': trimmed,
        'include_adult': 'false',
        'language': language,
        'region': region,
        'page': '1',
      },
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw TmdbException(
        'TMDB-Suche fehlgeschlagen (${response.statusCode}). Prüfe deinen Token.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TmdbMovie.fromJson)
        .toList();
    return results;
  }

  Future<TmdbMovie> getMovieDetails(int id) async {
    _ensureConfigured();
    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/movie/$id',
      {
        'language': language,
      },
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw TmdbException(
        'Filmdetails konnten nicht geladen werden (${response.statusCode}).',
      );
    }

    return TmdbMovie.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
