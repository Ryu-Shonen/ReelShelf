import 'package:flutter/material.dart';

import '../models/release_component.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';

class BoxsetMoviePickerScreen extends StatefulWidget {
  const BoxsetMoviePickerScreen({super.key});

  @override
  State<BoxsetMoviePickerScreen> createState() =>
      _BoxsetMoviePickerScreenState();
}

class _BoxsetMoviePickerScreenState
    extends State<BoxsetMoviePickerScreen> {
  final _controller = TextEditingController();

  List<TmdbMovie> _results = const [];
  bool _loading = false;
  bool _imdbLoading = false;
  String? _error;
  int _searchSerial = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TmdbService _service(AppState state) => TmdbService(
        token: state.tmdbToken,
        language: state.language,
        region: state.region,
      );

  Future<void> _search() async {
    final serial = ++_searchSerial;
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    final state = AppStateScope.of(context);

    setState(() {
      _loading = true;
      _imdbLoading = false;
      _error = null;
    });

    try {
      final results =
          await _service(state).searchMovies(query);
      if (!mounted) return;

      setState(() {
        _results = results;
        _loading = false;
        _imdbLoading = results.isNotEmpty;
      });

      if (results.isEmpty) return;

      try {
        final enriched =
            await state.enrichMoviesWithImdbRatings(results);
        if (!mounted || serial != _searchSerial) return;
        setState(() => _results = enriched);
      } catch (_) {
        // Search stays usable when IMDb is unavailable.
      } finally {
        if (mounted) {
          setState(() => _imdbLoading = false);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(TmdbMovie movie) {
    Navigator.of(context).pop(
      ReleaseComponent.fromTmdbMovie(
        movie,
        releaseId: 0,
        sequenceNumber: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final configured = state.tmdbToken.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Film zum Boxset hinzufügen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _controller,
              enabled: configured && !_loading,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: configured
                    ? 'Film suchen'
                    : 'TMDB-Token zuerst einrichten',
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: IconButton(
                  onPressed:
                      configured && !_loading ? _search : null,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          if (_imdbLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'IMDb-Bewertungen werden ergänzt …',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        configured
                            ? 'Suche den Film, der physisch in diesem Boxset enthalten ist.'
                            : 'Für die Filmsuche wird TMDB benötigt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movie = _results[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _select(movie),
                          child: SizedBox(
                            height: 116,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 78,
                                  height: 116,
                                  child: MoviePoster(
                                    url: movie.posterUrl,
                                    borderRadius: 0,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movie.title,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        [
                                          movie.year?.toString() ??
                                              'Jahr unbekannt',
                                          if (movie.imdbRating != null)
                                            'IMDb ${movie.imdbRating!.toStringAsFixed(1)}',
                                        ].join(' · '),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.add_circle_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
