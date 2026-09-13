import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/imdb_rating.dart';
import '../models/tmdb_movie.dart';
import 'database_service.dart';
import 'tmdb_service.dart';

class ImdbRatingsException implements Exception {
  const ImdbRatingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImdbRatingsService {
  static const String datasetUrl =
      'https://datasets.imdbws.com/title.ratings.tsv.gz';
  static const Duration cacheMaxAge = Duration(days: 7);

  Future<File>? _activeDatasetPreparation;

  Future<List<TmdbMovie>> enrichMovies({
    required List<TmdbMovie> movies,
    required TmdbService tmdbService,
    required DatabaseService database,
    bool forceDatasetRefresh = false,
  }) async {
    if (movies.isEmpty) return const [];

    final tmdbIds = movies.map((movie) => movie.id).toSet().toList();
    final cached =
        await database.getImdbRatingsForTmdbIds(tmdbIds);

    final fresh = <int, ImdbRating>{};
    final needsRefresh = <TmdbMovie>[];

    for (final movie in movies) {
      final entry = cached[movie.id];
      if (!forceDatasetRefresh &&
          entry != null &&
          entry.isFresh(cacheMaxAge)) {
        fresh[movie.id] = entry;
      } else {
        needsRefresh.add(movie);
      }
    }

    if (needsRefresh.isNotEmpty) {
      final imdbIds = <int, String>{};

      for (final movie in needsRefresh) {
        final existingId = cached[movie.id]?.imdbId.trim() ?? '';
        final embeddedId = movie.imdbId?.trim() ?? '';

        if (embeddedId.isNotEmpty) {
          imdbIds[movie.id] = embeddedId;
        } else if (existingId.isNotEmpty) {
          imdbIds[movie.id] = existingId;
        }
      }

      final missingIds = needsRefresh
          .where((movie) => !imdbIds.containsKey(movie.id))
          .toList();

      for (var offset = 0; offset < missingIds.length; offset += 5) {
        final end = offset + 5 < missingIds.length
            ? offset + 5
            : missingIds.length;
        final batch = missingIds.sublist(offset, end);

        final resolved = await Future.wait(
          batch.map((movie) async {
            final imdbId =
                await tmdbService.getMovieImdbId(movie.id);
            return MapEntry(movie.id, imdbId);
          }),
        );

        for (final entry in resolved) {
          final imdbId = entry.value?.trim() ?? '';
          if (imdbId.isNotEmpty) {
            imdbIds[entry.key] = imdbId;
          }
        }
      }

      final wantedIds = imdbIds.values.toSet();
      final ratings = <String, _RawImdbRating>{};

      if (wantedIds.isNotEmpty) {
        final file = await _ensureDataset(
          forceRefresh: forceDatasetRefresh,
        );
        ratings.addAll(
          await _readRatings(
            file: file,
            wantedIds: wantedIds,
          ),
        );
      }

      final now = DateTime.now();
      final updates = <ImdbRating>[];

      for (final movie in needsRefresh) {
        final imdbId = imdbIds[movie.id] ?? '';
        final raw = ratings[imdbId];

        updates.add(
          ImdbRating(
            tmdbId: movie.id,
            imdbId: imdbId,
            rating: raw?.rating,
            voteCount: raw?.voteCount,
            updatedAt: now,
          ),
        );
      }

      await database.upsertImdbRatings(updates);
      fresh.addEntries(
        updates.map((entry) => MapEntry(entry.tmdbId, entry)),
      );
    }

    return movies.map((movie) {
      final rating = fresh[movie.id] ?? cached[movie.id];
      if (rating == null) return movie;

      return movie.withImdb(
        imdbId:
            rating.imdbId.isEmpty ? movie.imdbId : rating.imdbId,
        rating: rating.rating,
        voteCount: rating.voteCount,
      );
    }).toList();
  }

  Future<File> _ensureDataset({
    required bool forceRefresh,
  }) {
    final running = _activeDatasetPreparation;
    if (running != null) return running;

    late final Future<File> future;
    future = _prepareDataset(forceRefresh: forceRefresh)
        .whenComplete(() {
      if (identical(_activeDatasetPreparation, future)) {
        _activeDatasetPreparation = null;
      }
    });

    _activeDatasetPreparation = future;
    return future;
  }

  Future<File> _prepareDataset({
    required bool forceRefresh,
  }) async {
    final root = await getDatabasesPath();
    final file = File(
      p.join(root, 'imdb_title_ratings.tsv.gz'),
    );

    final exists = await file.exists();

    if (exists && !forceRefresh) {
      final modified = await file.lastModified();
      if (DateTime.now().difference(modified) < cacheMaxAge) {
        return file;
      }
    }

    final temp = File('${file.path}.download');
    final client = http.Client();

    try {
      if (await temp.exists()) {
        await temp.delete();
      }

      final request =
          http.Request('GET', Uri.parse(datasetUrl));
      request.headers['User-Agent'] = 'ReelShelf/0.4.3';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw ImdbRatingsException(
          'IMDb-Datensatz konnte nicht geladen werden (${response.statusCode}).',
        );
      }

      final sink = temp.openWrite();
      await response.stream.pipe(sink);

      if (!await temp.exists() ||
          await temp.length() < 1024) {
        throw const ImdbRatingsException(
          'Der geladene IMDb-Datensatz ist ungültig.',
        );
      }

      if (await file.exists()) {
        await file.delete();
      }

      return await temp.rename(file.path);
    } catch (error) {
      if (await temp.exists()) {
        await temp.delete();
      }

      if (exists && await file.exists()) {
        return file;
      }

      if (error is ImdbRatingsException) rethrow;
      throw ImdbRatingsException(
        'IMDb-Bewertungen konnten nicht vorbereitet werden: $error',
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, _RawImdbRating>> _readRatings({
    required File file,
    required Set<String> wantedIds,
  }) async {
    if (wantedIds.isEmpty) return const {};

    final result = <String, _RawImdbRating>{};

    try {
      final lines = file
          .openRead()
          .transform(gzip.decoder)
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty || line.startsWith('tconst')) {
          continue;
        }

        final firstTab = line.indexOf('\t');
        if (firstTab <= 0) continue;

        final imdbId = line.substring(0, firstTab);
        if (!wantedIds.contains(imdbId)) continue;

        final secondTab =
            line.indexOf('\t', firstTab + 1);
        if (secondTab <= firstTab) continue;

        final rawRating =
            line.substring(firstTab + 1, secondTab);
        final rawVotes = line.substring(secondTab + 1);

        final rating = double.tryParse(rawRating);
        final votes = int.tryParse(rawVotes);

        if (rating != null) {
          result[imdbId] = _RawImdbRating(
            rating: rating,
            voteCount: votes,
          );
        }

        if (result.length == wantedIds.length) {
          break;
        }
      }

      return result;
    } catch (error) {
      throw ImdbRatingsException(
        'Der lokale IMDb-Datensatz konnte nicht gelesen werden: $error',
      );
    }
  }
}

class _RawImdbRating {
  const _RawImdbRating({
    required this.rating,
    required this.voteCount,
  });

  final double rating;
  final int? voteCount;
}
