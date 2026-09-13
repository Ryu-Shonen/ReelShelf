import 'dart:io';

import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/tmdb_movie.dart';
import '../services/cover_scan_service.dart';
import '../services/tmdb_service.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'edit_item_screen.dart';
import 'settings_screen.dart';

class AddMovieScreen extends StatefulWidget {
  const AddMovieScreen({
    super.key,
    this.initialWishlist = false,
    this.autoScanCover = false,
  });

  final bool initialWishlist;
  final bool autoScanCover;

  @override
  State<AddMovieScreen> createState() => _AddMovieScreenState();
}

class _AddMovieScreenState extends State<AddMovieScreen> {
  final _searchController = TextEditingController();
  final _coverScanService = CoverScanService();

  List<TmdbMovie> _results = const [];
  bool _loading = false;
  bool _imdbLoading = false;
  bool _coverScanning = false;
  String? _error;
  String? _coverImagePath;
  String? _coverSummary;
  late bool _wishlist;
  int _searchSerial = 0;

  @override
  void initState() {
    super.initState();
    _wishlist = widget.initialWishlist;

    if (widget.autoScanCover) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanCover();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TmdbService _service(AppState state) => TmdbService(
        token: state.tmdbToken,
        language: state.language,
        region: state.region,
      );

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final serial = ++_searchSerial;
    FocusScope.of(context).unfocus();
    final state = AppStateScope.of(context);

    setState(() {
      _loading = true;
      _imdbLoading = false;
      _error = null;
    });

    try {
      final result = await _service(state).searchMovies(query);
      if (!mounted || serial != _searchSerial) return;

      await _showResultsWithImdb(
        result,
        serial: serial,
      );
    } catch (error) {
      if (!mounted || serial != _searchSerial) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && serial == _searchSerial && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _scanCover() async {
    final state = AppStateScope.of(context);

    if (state.tmdbToken.trim().isEmpty) {
      setState(() {
        _error =
            'Bitte zuerst den TMDB Read Access Token in den Einstellungen einrichten.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _coverScanning = true;
      _loading = false;
      _imdbLoading = false;
      _error = null;
      _results = const [];
    });

    try {
      final scan = await _coverScanService.scanCover();
      if (!mounted) return;

      if (scan == null) {
        setState(() => _coverScanning = false);
        return;
      }

      if (scan.searchQueries.isEmpty) {
        setState(() {
          _coverScanning = false;
          _coverImagePath = scan.imagePath;
          _coverSummary = scan.summary;
          _error =
              'Auf dem Cover wurde kein geeigneter Filmtitel erkannt. Versuche das Cover möglichst gerade und ohne Spiegelung zu fotografieren.';
        });
        return;
      }

      final serial = ++_searchSerial;

      setState(() {
        _coverImagePath = scan.imagePath;
        _coverSummary = scan.summary;
        _searchController.text = scan.searchQueries.first;
        _coverScanning = false;
        _loading = true;
      });

      final service = _service(state);
      final moviesById = <int, TmdbMovie>{};

      for (final query in scan.searchQueries.take(4)) {
        try {
          final matches = await service.searchMovies(query);
          for (final movie in matches.take(8)) {
            moviesById.putIfAbsent(movie.id, () => movie);
          }
        } catch (_) {
          // Try the remaining OCR candidates.
        }
      }

      if (!mounted || serial != _searchSerial) return;

      final ranked = moviesById.values.toList()
        ..sort(
          (a, b) => _coverMatchScore(
            b,
            scan.rawText,
          ).compareTo(
            _coverMatchScore(a, scan.rawText),
          ),
        );

      final result = ranked.take(12).toList(growable: false);

      if (result.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'Der Text wurde erkannt, aber TMDB hat keinen passenden Film gefunden. Du kannst den erkannten Suchtext oben anpassen.';
        });
        return;
      }

      await _showResultsWithImdb(
        result,
        serial: serial,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _coverScanning = false;
        _loading = false;
        _error =
            'Cover konnte nicht erkannt werden: $error';
      });
    }
  }

  double _coverMatchScore(
    TmdbMovie movie,
    String rawText,
  ) {
    final haystack = _normalize(rawText);
    final title = _normalize(movie.title);
    final originalTitle = _normalize(
      movie.originalTitle ?? '',
    );

    var score = 0.0;

    if (title.isNotEmpty && haystack.contains(title)) {
      score += 120;
    }

    if (originalTitle.isNotEmpty &&
        haystack.contains(originalTitle)) {
      score += 90;
    }

    final titleTokens = title
        .split(' ')
        .where((token) => token.length >= 2)
        .toSet();

    if (titleTokens.isNotEmpty) {
      final matched = titleTokens
          .where((token) => haystack.contains(token))
          .length;

      score +=
          (matched / titleTokens.length) * 80;
    }

    final year = movie.year;
    if (year != null && haystack.contains('$year')) {
      score += 20;
    }

    score += (movie.voteAverage ?? 0) * 0.15;

    return score;
  }

  String _normalize(String value) {
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

  Future<void> _showResultsWithImdb(
    List<TmdbMovie> result, {
    required int serial,
  }) async {
    if (!mounted || serial != _searchSerial) return;

    setState(() {
      _results = result;
      _loading = false;
      _imdbLoading = result.isNotEmpty;
    });

    if (result.isEmpty) {
      setState(() => _imdbLoading = false);
      return;
    }

    final state = AppStateScope.of(context);

    try {
      final enriched =
          await state.enrichMoviesWithImdbRatings(result);
      if (!mounted || serial != _searchSerial) return;
      setState(() => _results = enriched);
    } catch (_) {
      // TMDB results stay usable even when IMDb is unavailable.
    } finally {
      if (mounted && serial == _searchSerial) {
        setState(() => _imdbLoading = false);
      }
    }
  }

  Future<void> _selectMovie(TmdbMovie movie) async {
    final state = AppStateScope.of(context);
    setState(() => _loading = true);

    try {
      final details =
          await _service(state).getMovieDetails(movie.id);
      if (!mounted) return;

      var ratedDetails = details;

      try {
        final enriched =
            await state.enrichMoviesWithImdbRatings([details]);
        if (enriched.isNotEmpty) {
          ratedDetails = enriched.first;
        }
      } catch (_) {
        // Adding the film must still work without IMDb.
      }

      final item = ratedDetails
          .toCollectionItem()
          .copyWith(wishlist: _wishlist);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditItemScreen(
            item: item,
            isNew: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manual({bool boxSet = false}) async {
    final now = DateTime.now();

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          item: CollectionItem(
            title: '',
            wishlist: _wishlist,
            mediaFormat: boxSet ? 'Boxset' : 'Blu-ray',
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final configured = state.tmdbToken.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _wishlist ? 'Zur Wunschliste' : 'Film hinzufügen',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Sammlung'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.bookmark_rounded),
                      label: Text('Wunschliste'),
                    ),
                  ],
                  selected: <bool>{_wishlist},
                  onSelectionChanged: (selection) {
                    setState(() => _wishlist = selection.first);
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Cover erkennen',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                FilledButton.tonalIcon(
                  onPressed: configured &&
                          !_coverScanning &&
                          !_loading
                      ? _scanCover
                      : null,
                  icon: _coverScanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_rounded,
                        ),
                  label: Text(
                    _coverScanning
                        ? 'Cover wird analysiert …'
                        : 'Filmcover scannen',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Fotografiere die Vorderseite möglichst gerade, scharf und ohne starke Spiegelung. Unstreamed liest den Titel lokal aus dem Foto und sucht passende Filme bei TMDB.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                if (_coverImagePath != null) ...[
                  const SizedBox(height: 12),
                  _CoverScanCard(
                    imagePath: _coverImagePath!,
                    summary: _coverSummary,
                    onRescan: _coverScanning ? null : _scanCover,
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Film bei TMDB',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _searchController,
                  enabled:
                      configured && !_loading && !_coverScanning,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: configured
                        ? 'Film suchen, z. B. Prinzessin Mononoke'
                        : 'TMDB-Token zuerst einrichten',
                    prefixIcon: const Icon(Icons.movie_outlined),
                    suffixIcon: IconButton(
                      onPressed: configured &&
                              !_loading &&
                              !_coverScanning
                          ? _search
                          : null,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                      ),
                    ),
                  ),
                ),
                if (_imdbLoading) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'IMDb-Bewertungen werden ergänzt …',
                        style: TextStyle(
                          color:
                              Colors.white.withValues(alpha: 0.5),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _manual(),
                        icon:
                            const Icon(Icons.edit_note_rounded),
                        label: Text(
                          _wishlist
                              ? 'Wunsch manuell'
                              : 'Film manuell',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _manual(boxSet: true),
                        icon: const Icon(
                          Icons.all_inbox_rounded,
                        ),
                        label:
                            const Text('Boxset anlegen'),
                      ),
                    ),
                  ],
                ),
                if (!configured) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automatische Filmdaten aktivieren',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Für Cover-Erkennung und automatische Filmdaten benötigt Unstreamed einen kostenlosen TMDB Read Access Token.',
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(
                                alpha: 0.62,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SettingsScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.key_rounded),
                            label:
                                const Text('Token einrichten'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        configured
                            ? 'Scanne das Frontcover oder suche den Film direkt bei TMDB.'
                            : 'Du kannst Filme manuell erfassen. Für Cover-Erkennung und automatische Filmdaten richtest du einmalig TMDB ein.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              Colors.white.withValues(alpha: 0.5),
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      28,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movie = _results[index];

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _loading
                              ? null
                              : () => _selectMovie(movie),
                          child: SizedBox(
                            height: 132,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 88,
                                  height: 132,
                                  child: MoviePoster(
                                    url: movie.posterUrl,
                                    borderRadius: 0,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          movie.title,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            movie.year
                                                    ?.toString() ??
                                                'Jahr unbekannt',
                                            if (movie.voteAverage !=
                                                null)
                                              'TMDB ${movie.voteAverage!.toStringAsFixed(1)}',
                                            if (movie.imdbRating !=
                                                null)
                                              'IMDb ${movie.imdbRating!.toStringAsFixed(1)}',
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Text(
                                            movie.overview
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? movie.overview!
                                                : 'Keine Beschreibung verfügbar.',
                                            maxLines: 3,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.3,
                                              color: Colors.white
                                                  .withValues(
                                                alpha: 0.62,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
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

class _CoverScanCard extends StatelessWidget {
  const _CoverScanCard({
    required this.imagePath,
    required this.summary,
    required this.onRescan,
  });

  final String imagePath;
  final String? summary;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 64,
                height: 92,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(
                    color: Color(0xFF171920),
                    child: Icon(
                      Icons.image_not_supported_outlined,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cover analysiert',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    summary?.trim().isNotEmpty == true
                        ? summary!
                        : 'Text erkannt und mit TMDB abgeglichen.',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: 0.58),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRescan,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Nochmal scannen',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
