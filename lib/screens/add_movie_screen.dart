import 'package:flutter/material.dart';

import '../models/collection_item.dart';
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
  String? _error;
  String? _barcode;
  late bool _wishlist;

  @override
  void initState() {
    super.initState();
    _barcode = widget.initialBarcode;
    _wishlist = widget.initialWishlist;
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
      final result = await _service(state).searchMovies(_searchController.text);
      if (!mounted) return;
      setState(() => _results = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectMovie(TmdbMovie movie) async {
    final state = AppStateScope.of(context);
    setState(() => _loading = true);
    try {
      final details = await _service(state).getMovieDetails(movie.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditItemScreen(
            item: details
                .toCollectionItem(ean: _barcode ?? '')
                .copyWith(wishlist: _wishlist),
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

  Future<void> _manual() async {
    final now = DateTime.now();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          item: CollectionItem(
            title: '',
            ean: _barcode ?? '',
            wishlist: _wishlist,
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
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || result == null) return;
    setState(() => _barcode = result);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final configured = state.tmdbToken.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_wishlist ? 'Zur Wunschliste' : 'Film hinzufügen'),
        actions: [
          IconButton(
            tooltip: 'Barcode scannen',
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
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
                const SizedBox(height: 12),
                if (_barcode != null && _barcode!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B7A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF6B7A).withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'EAN $_barcode',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _barcode = null),
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _searchController,
                  enabled: configured && !_loading,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: configured
                        ? 'Film suchen, z. B. Prinzessin Mononoke'
                        : 'TMDB-Token zuerst einrichten',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: configured && !_loading ? _search : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _manual,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(
                    _wishlist
                        ? 'Wunsch manuell anlegen'
                        : 'Film manuell anlegen',
                  ),
                ),
                if (!configured) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.key_rounded),
                            label: const Text('Token einrichten'),
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
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        configured
                            ? _wishlist
                                ? 'Suche einen Film bei TMDB und füge ihn deiner Wunschliste hinzu.'
                                : 'Suche einen Film bei TMDB oder lege deine Ausgabe manuell an.'
                            : 'Du kannst bereits manuell Filme erfassen. Für die automatische Suche richtest du einmalig TMDB ein.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movie = _results[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _loading ? null : () => _selectMovie(movie),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          movie.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          movie.year?.toString() ??
                                              'Jahr unbekannt',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Text(
                                            movie.overview?.trim().isNotEmpty ==
                                                    true
                                                ? movie.overview!
                                                : 'Keine Beschreibung verfügbar.',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.3,
                                              color: Colors.white.withValues(
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
                                  child: Icon(Icons.chevron_right_rounded),
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
