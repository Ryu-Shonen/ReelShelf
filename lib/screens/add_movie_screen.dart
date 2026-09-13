import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/physical_release.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'barcode_scanner_screen.dart';
import 'edit_item_screen.dart';
import 'settings_screen.dart';

class AddMovieScreen extends StatefulWidget {
  const AddMovieScreen({
    super.key,
    this.initialBarcode,
    this.initialWishlist = false,
  });

  final String? initialBarcode;
  final bool initialWishlist;

  @override
  State<AddMovieScreen> createState() => _AddMovieScreenState();
}

class _AddMovieScreenState extends State<AddMovieScreen> {
  final _searchController = TextEditingController();

  List<TmdbMovie> _results = const [];
  bool _loading = false;
  bool _imdbLoading = false;
  bool _releaseLoading = false;
  String? _error;
  String? _releaseMessage;
  String? _barcode;
  PhysicalRelease? _cachedRelease;
  late bool _wishlist;
  int _searchSerial = 0;

  @override
  void initState() {
    super.initState();
    _barcode = widget.initialBarcode;
    _wishlist = widget.initialWishlist;

    if (_barcode?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookupLocalRelease(_barcode!);
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
    final serial = ++_searchSerial;
    FocusScope.of(context).unfocus();
    final state = AppStateScope.of(context);

    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _imdbLoading = false;
      _error = null;
    });

    try {
      final result =
          await _service(state).searchMovies(_searchController.text);
      if (!mounted) return;

      setState(() {
        _results = result;
        _loading = false;
        _imdbLoading = result.isNotEmpty;
      });

      if (result.isEmpty) return;

      try {
        final enriched =
            await state.enrichMoviesWithImdbRatings(result);
        if (!mounted || serial != _searchSerial) return;
        setState(() => _results = enriched);
      } catch (_) {
        // TMDB search results stay usable even if IMDb is unavailable.
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

  CollectionItem _applyReleaseData(CollectionItem item) {
    final release = _cachedRelease;

    if (release != null) {
      return release.applyTo(
        item.copyWith(ean: _barcode ?? release.ean),
        wishlist: _wishlist,
      );
    }

    return item.copyWith(
      ean: _barcode ?? item.ean,
      wishlist: _wishlist,
    );
  }

  Future<void> _selectMovie(TmdbMovie movie) async {
    final state = AppStateScope.of(context);
    setState(() => _loading = true);

    try {
      final details = await _service(state).getMovieDetails(movie.id);
      if (!mounted) return;

      var ratedDetails = details;
      try {
        final enriched =
            await state.enrichMoviesWithImdbRatings([details]);
        if (enriched.isNotEmpty) {
          ratedDetails = enriched.first;
        }
      } catch (_) {
        // Adding the film must still work if IMDb is temporarily unavailable.
      }

      final base =
          ratedDetails.toCollectionItem(ean: _barcode ?? '');
      final item = _applyReleaseData(base);

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

  Future<void> _useCachedRelease() async {
    final release = _cachedRelease;
    if (release == null) return;

    final state = AppStateScope.of(context);
    final configured = state.tmdbToken.trim().isNotEmpty;

    if (release.tmdbId == null || !configured) {
      await _manual();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final details =
          await _service(state).getMovieDetails(release.tmdbId!);
      if (!mounted) return;

      var ratedDetails = details;
      try {
        final enriched =
            await state.enrichMoviesWithImdbRatings([details]);
        if (enriched.isNotEmpty) {
          ratedDetails = enriched.first;
        }
      } catch (_) {
        // Cached physical releases remain usable without IMDb.
      }

      final item = release.applyTo(
        ratedDetails.toCollectionItem(ean: release.ean),
        wishlist: _wishlist,
      );

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
    final release = _cachedRelease;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          item: CollectionItem(
            releaseId: release?.id,
            tmdbId: release?.tmdbId,
            title: release?.title ?? '',
            ean: _barcode ?? release?.ean ?? '',
            wishlist: _wishlist,
            mediaFormat: boxSet ? 'Boxset' : (release?.mediaFormat ?? 'Blu-ray'),
            edition: release?.edition ?? '',
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final normalized = PhysicalRelease.normalizeBarcode(result);
    setState(() {
      _barcode = normalized;
      _cachedRelease = null;
      _releaseMessage = null;
      _results = const [];
    });

    await _lookupLocalRelease(normalized);
  }

  Future<void> _lookupLocalRelease(String barcode) async {
    final value = PhysicalRelease.normalizeBarcode(barcode);
    if (value.isEmpty) return;

    setState(() {
      _releaseLoading = true;
      _releaseMessage = null;
    });

    final state = AppStateScope.of(context);
    final release = state.findReleaseByEan(value);

    if (!mounted) return;

    setState(() {
      _barcode = value;
      _cachedRelease = release;

      if (release == null) {
        _releaseMessage =
            'EAN erkannt. Diese Ausgabe kennt ReelShelf noch nicht. Ordne unten den Film zu; beim Speichern merkt sich ReelShelf diese EAN dauerhaft lokal.';
      } else {
        _releaseMessage =
            'Lokaler Treffer – dafür wurde keine externe Produktdatenbank abgefragt.';
        if (_searchController.text.trim().isEmpty) {
          _searchController.text = release.title;
        }
      }

      _releaseLoading = false;
    });
  }

  void _clearBarcode() {
    setState(() {
      _cachedRelease = null;
      _releaseMessage = null;
      _barcode = null;
    });
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
                  'Physische Ausgabe',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _releaseLoading ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Barcode scannen'),
                  ),
                ),
                if (_releaseLoading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_cachedRelease != null) ...[
                  const SizedBox(height: 10),
                  _LocalReleaseCard(
                    release: _cachedRelease!,
                    message: _releaseMessage,
                    onUse: _loading ? null : _useCachedRelease,
                    onClear: _clearBarcode,
                  ),
                ] else if (_barcode?.isNotEmpty == true ||
                    _releaseMessage != null) ...[
                  const SizedBox(height: 10),
                  _BarcodeStatusCard(
                    barcode: _barcode,
                    message: _releaseMessage,
                    onClear: _clearBarcode,
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
                  enabled: configured && !_loading,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: configured
                        ? 'Film suchen, z. B. Prinzessin Mononoke'
                        : 'TMDB-Token zuerst einrichten',
                    prefixIcon: const Icon(Icons.movie_outlined),
                    suffixIcon: IconButton(
                      onPressed:
                          configured && !_loading ? _search : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
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
                          color: Colors.white.withValues(alpha: 0.5),
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
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(
                          _wishlist
                              ? 'Wunsch manuell'
                              : 'Ausgabe manuell',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _manual(boxSet: true),
                        icon: const Icon(Icons.all_inbox_rounded),
                        label: const Text('Boxset anlegen'),
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
                            'Für Cover, Laufzeit und Beschreibung benötigt ReelShelf einen kostenlosen TMDB Read Access Token.',
                            style: TextStyle(
                              color: Colors.white.withValues(
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
                    style:
                        const TextStyle(color: Colors.redAccent),
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
                            ? _barcode?.isNotEmpty == true
                                ? 'Wähle den passenden Film. Beim Speichern wird die EAN mit dieser physischen Ausgabe lokal verknüpft.'
                                : 'Scanne zuerst eine Ausgabe oder suche direkt einen Film bei TMDB.'
                            : 'Du kannst Filme bereits manuell erfassen. Für automatische Filmdaten richtest du einmalig TMDB ein.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.5,
                          ),
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                                            movie.year?.toString() ??
                                                'Jahr unbekannt',
                                            if (movie.voteAverage != null)
                                              'TMDB ${movie.voteAverage!.toStringAsFixed(1)}',
                                            if (movie.imdbRating != null)
                                              'IMDb ${movie.imdbRating!.toStringAsFixed(1)}',
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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

class _LocalReleaseCard extends StatelessWidget {
  const _LocalReleaseCard({
    required this.release,
    required this.message,
    required this.onUse,
    required this.onClear,
  });

  final PhysicalRelease release;
  final String? message;
  final VoidCallback? onUse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.offline_pin_rounded,
                  color: Color(0xFFFF6B7A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokal gespeichert',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        release.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (release.edition.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          release.edition,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _MiniChip(release.mediaFormat),
                          _MiniChip('EAN ${release.ean}'),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Barcode entfernen',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 11),
            FilledButton.tonalIcon(
              onPressed: onUse,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Lokalen Treffer verwenden'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeStatusCard extends StatelessWidget {
  const _BarcodeStatusCard({
    required this.barcode,
    required this.message,
    required this.onClear,
  });

  final String? barcode;
  final String? message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (barcode?.isNotEmpty == true)
                  Text(
                    'EAN $barcode',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (message != null) ...[
                  if (barcode?.isNotEmpty == true)
                    const SizedBox(height: 4),
                  Text(
                    message!,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: 0.58),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
