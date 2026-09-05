import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import '../services/upc_itemdb_service.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'barcode_scanner_screen.dart';
import 'edit_item_screen.dart';
import 'physical_release_search_screen.dart';
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
  final _upcService = const UpcItemDbService();

  List<TmdbMovie> _results = const [];
  bool _loading = false;
  bool _physicalLoading = false;
  String? _error;
  String? _physicalMessage;
  String? _barcode;
  UpcItem? _physicalItem;
  late bool _wishlist;

  @override
  void initState() {
    super.initState();
    _barcode = widget.initialBarcode;
    _wishlist = widget.initialWishlist;

    if (_barcode?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookupBarcode(_barcode!);
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
    FocusScope.of(context).unfocus();
    final state = AppStateScope.of(context);

    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await _service(state).searchMovies(_searchController.text);
      if (!mounted) return;
      setState(() => _results = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CollectionItem _applyPhysicalData(
    CollectionItem item, {
    required String movieTitle,
  }) {
    final physical = _physicalItem;

    return item.copyWith(
      ean: _barcode ?? item.ean,
      wishlist: _wishlist,
      mediaFormat: physical?.suggestedMediaFormat ?? item.mediaFormat,
      edition:
          physical?.editionForMovie(movieTitle) ?? item.edition,
    );
  }

  Future<void> _selectMovie(TmdbMovie movie) async {
    final state = AppStateScope.of(context);

    setState(() => _loading = true);

    try {
      final details = await _service(state).getMovieDetails(movie.id);
      if (!mounted) return;

      final base = details.toCollectionItem(ean: _barcode ?? '');
      final item = _applyPhysicalData(
        base,
        movieTitle: details.title,
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

  Future<void> _manual({bool preferPhysicalTitle = false}) async {
    final now = DateTime.now();
    final physical = _physicalItem;

    String title = '';
    if (physical != null) {
      title = preferPhysicalTitle || physical.isLikelyBoxSet
          ? physical.title
          : physical.suggestedMovieQuery;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          item: CollectionItem(
            title: title,
            ean: _barcode ?? physical?.ean ?? '',
            wishlist: _wishlist,
            mediaFormat:
                physical?.suggestedMediaFormat ?? 'Blu-ray',
            edition: physical != null &&
                    !physical.isLikelyBoxSet &&
                    title != physical.title
                ? physical.title
                : '',
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

    setState(() {
      _barcode = result.trim();
      _physicalItem = null;
      _physicalMessage = null;
    });

    await _lookupBarcode(result);
  }

  Future<void> _lookupBarcode(String barcode) async {
    final value = barcode.trim();
    if (value.isEmpty) return;

    setState(() {
      _physicalLoading = true;
      _physicalMessage = null;
    });

    try {
      final product = await _upcService.lookup(value);
      if (!mounted) return;

      if (product == null) {
        setState(() {
          _physicalItem = null;
          _physicalMessage =
              'Barcode erkannt, aber diese Ausgabe wurde in UPCitemdb nicht gefunden. Die EAN bleibt trotzdem gespeichert.';
        });
        return;
      }

      setState(() {
        _physicalItem = product;
        _barcode =
            product.ean.isNotEmpty ? product.ean : value;
        _physicalMessage = null;

        if (_searchController.text.trim().isEmpty) {
          _searchController.text = product.suggestedMovieQuery;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _physicalItem = null;
        _physicalMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _physicalLoading = false);
    }
  }

  Future<void> _searchPhysicalRelease() async {
    final result = await Navigator.of(context).push<UpcItem>(
      MaterialPageRoute(
        builder: (_) => const PhysicalReleaseSearchScreen(),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _physicalItem = result;
      _barcode = result.ean.isNotEmpty ? result.ean : _barcode;
      _physicalMessage = null;

      if (_searchController.text.trim().isEmpty) {
        _searchController.text = result.suggestedMovieQuery;
      }
    });
  }

  void _clearPhysicalRelease() {
    setState(() {
      _physicalItem = null;
      _physicalMessage = null;
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
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed:
                            _physicalLoading ? null : _scan,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                        ),
                        label: const Text('Barcode scannen'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _physicalLoading
                            ? null
                            : _searchPhysicalRelease,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Ausgabe suchen'),
                      ),
                    ),
                  ],
                ),
                if (_physicalLoading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_physicalItem != null) ...[
                  const SizedBox(height: 10),
                  _PhysicalReleaseCard(
                    item: _physicalItem!,
                    barcode: _barcode,
                    onClear: _clearPhysicalRelease,
                    onCreateBoxSet: _physicalItem!.isLikelyBoxSet
                        ? () => _manual(preferPhysicalTitle: true)
                        : null,
                  ),
                ] else if (_barcode?.isNotEmpty == true ||
                    _physicalMessage != null) ...[
                  const SizedBox(height: 10),
                  _BarcodeStatusCard(
                    barcode: _barcode,
                    message: _physicalMessage,
                    onClear: _clearPhysicalRelease,
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
                      icon:
                          const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _manual(
                    preferPhysicalTitle:
                        _physicalItem?.isLikelyBoxSet == true,
                  ),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(
                    _wishlist
                        ? 'Wunsch manuell anlegen'
                        : _physicalItem?.isLikelyBoxSet == true
                            ? 'Boxset manuell anlegen'
                            : 'Film manuell anlegen',
                  ),
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
                            ? _physicalItem?.isLikelyBoxSet ==
                                    true
                                ? 'Für Collections und Boxsets kannst du den physischen Eintrag direkt manuell anlegen. Für einzelne Filme kannst du zusätzlich TMDB zuordnen.'
                                : _wishlist
                                    ? 'Suche einen Film bei TMDB und füge ihn deiner Wunschliste hinzu.'
                                    : 'Suche einen Film bei TMDB oder lege deine Ausgabe manuell an.'
                            : 'Du kannst bereits manuell Filme und Boxsets erfassen. Für die automatische Filmsuche richtest du einmalig TMDB ein.',
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
                                          movie.year?.toString() ??
                                              'Jahr unbekannt',
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

class _PhysicalReleaseCard extends StatelessWidget {
  const _PhysicalReleaseCard({
    required this.item,
    required this.barcode,
    required this.onClear,
    this.onCreateBoxSet,
  });

  final UpcItem item;
  final String? barcode;
  final VoidCallback onClear;
  final VoidCallback? onCreateBoxSet;

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
                _PhysicalImage(url: item.primaryImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (item.brand.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          item.brand,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _MiniChip(item.suggestedMediaFormat),
                          if (barcode?.isNotEmpty == true)
                            _MiniChip('EAN $barcode'),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ausgabe entfernen',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (onCreateBoxSet != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: onCreateBoxSet,
                icon: const Icon(Icons.all_inbox_rounded),
                label: const Text(
                  'Diese Collection als Boxset anlegen',
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'Diese Ausgabedaten werden übernommen, sobald du unten den passenden Film auswählst.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhysicalImage extends StatelessWidget {
  const _PhysicalImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
      ),
      child: url == null
          ? const Icon(Icons.album_outlined)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.album_outlined),
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
