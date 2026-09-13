import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/physical_release.dart';
import '../models/release_component.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'boxset_movie_picker_screen.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({
    super.key,
    required this.item,
    required this.isNew,
  });

  final CollectionItem item;
  final bool isNew;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _edition;
  late final TextEditingController _ean;
  late final TextEditingController _price;
  late final TextEditingController _purchaseDate;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late String _format;
  late String _condition;
  late bool _favorite;
  late bool _wishlist;
  double? _userRating;
  bool _saving = false;
  bool _loadedComponents = false;
  List<ReleaseComponent> _components = const [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _title = TextEditingController(text: item.title);
    _edition = TextEditingController(text: item.edition);
    _ean = TextEditingController(text: item.ean);
    _price = TextEditingController(
      text: item.purchasePrice == null
          ? ''
          : item.purchasePrice!
              .toStringAsFixed(2)
              .replaceAll('.', ','),
    );
    _purchaseDate =
        TextEditingController(text: item.purchaseDate ?? '');
    _location = TextEditingController(text: item.location);
    _notes = TextEditingController(text: item.notes);
    _format = CollectionItem.mediaFormats.contains(item.mediaFormat)
        ? item.mediaFormat
        : 'Sonstiges';
    _condition =
        CollectionItem.conditions.contains(item.condition)
            ? item.condition
            : 'Sehr gut';
    _favorite = item.favorite;
    _wishlist = item.wishlist;
    _userRating = item.userRating;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedComponents) return;
    _loadedComponents = true;

    final releaseId = widget.item.releaseId;
    if (releaseId == null) return;

    _components = AppStateScope.of(context)
        .componentsForRelease(releaseId)
        .map((component) => component.copyWith())
        .toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _edition.dispose();
    _ean.dispose();
    _price.dispose();
    _purchaseDate.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addBoxsetMovie() async {
    final component =
        await Navigator.of(context).push<ReleaseComponent>(
      MaterialPageRoute(
        builder: (_) => const BoxsetMoviePickerScreen(),
      ),
    );

    if (!mounted || component == null) return;

    final duplicate = _components.any(
      (entry) =>
          entry.tmdbId != null &&
          entry.tmdbId == component.tmdbId,
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dieser Film ist bereits im Boxset enthalten.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _components = [
        ..._components,
        component.copyWith(
          sequenceNumber: _components.length,
        ),
      ];
    });
  }

  void _removeBoxsetMovie(int index) {
    setState(() {
      final updated = [..._components]..removeAt(index);
      _components = [
        for (var i = 0; i < updated.length; i++)
          updated[i].copyWith(sequenceNumber: i),
      ];
    });
  }

  void _moveBoxsetMovie(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _components.length) return;

    setState(() {
      final updated = [..._components];
      final item = updated.removeAt(index);
      updated.insert(target, item);
      _components = [
        for (var i = 0; i < updated.length; i++)
          updated[i].copyWith(sequenceNumber: i),
      ];
    });
  }

  Future<void> _pickDate() async {
    final initial =
        DateTime.tryParse(_purchaseDate.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;

    _purchaseDate.text =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    if (mounted) setState(() {});
  }

  double? _parsePrice() {
    final value = _price.text.trim().replaceAll(',', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  String _formatUserRating(double rating) {
    final fixed = rating % 1 == 0
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);
    return fixed.replaceAll('.', ',');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final base = widget.item;
    final now = DateTime.now();
    final normalizedEan =
        PhysicalRelease.normalizeBarcode(_ean.text);

    final item = CollectionItem(
      id: base.id,
      releaseId: base.releaseId,
      tmdbId: _format == 'Boxset' ? null : base.tmdbId,
      title: _title.text.trim(),
      originalTitle:
          _format == 'Boxset' ? null : base.originalTitle,
      year: _format == 'Boxset' ? null : base.year,
      releaseDate:
          _format == 'Boxset' ? null : base.releaseDate,
      posterPath:
          _format == 'Boxset' ? null : base.posterPath,
      backdropPath:
          _format == 'Boxset' ? null : base.backdropPath,
      overview:
          _format == 'Boxset' ? null : base.overview,
      runtime: _format == 'Boxset' ? null : base.runtime,
      genres: _format == 'Boxset' ? '' : base.genres,
      voteAverage:
          _format == 'Boxset' ? null : base.voteAverage,
      userRating: _format == 'Boxset' ? null : _userRating,
      originalLanguage:
          _format == 'Boxset' ? null : base.originalLanguage,
      mediaFormat: _format,
      edition: _edition.text.trim(),
      ean: normalizedEan,
      purchasePrice: _parsePrice(),
      purchaseDate: _purchaseDate.text.trim().isEmpty
          ? null
          : _purchaseDate.text.trim(),
      condition: _condition,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      favorite: _favorite,
      wishlist: _wishlist,
      createdAt: base.createdAt,
      updatedAt: now,
    );

    try {
      final saved = widget.isNew
          ? await state.addItem(item)
          : await state.updateItem(item);

      if (saved.releaseId != null) {
        await state.replaceReleaseComponents(
          saved.releaseId!,
          _format == 'Boxset' ? _components : const [],
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speichern fehlgeschlagen: $error'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  String get _primaryActionLabel {
    if (!widget.isNew) return 'Änderungen speichern';
    return _wishlist
        ? 'Zur Wunschliste hinzufügen'
        : _format == 'Boxset'
            ? 'Boxset zur Sammlung hinzufügen'
            : 'Zur Sammlung hinzufügen';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isBoxSet = _format == 'Boxset';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? (_wishlist
                  ? 'Wunsch hinzufügen'
                  : isBoxSet
                      ? 'Boxset hinzufügen'
                      : 'Ausgabe hinzufügen')
              : isBoxSet
                  ? 'Boxset bearbeiten'
                  : 'Ausgabe bearbeiten',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (!isBoxSet &&
                (item.posterUrl != null || item.title.isNotEmpty))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 108,
                        child: MoviePoster(
                          url: item.posterUrl,
                          borderRadius: 12,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title.isEmpty
                                    ? 'Manueller Eintrag'
                                    : item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (item.year != null)
                                    '${item.year}',
                                  if (item.runtime != null)
                                    '${item.runtime} Min.',
                                ].join(' · '),
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _SectionTitle('Speicherort'),
            const SizedBox(height: 10),
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
            const SizedBox(height: 22),
            _SectionTitle(
              isBoxSet ? 'Boxset' : 'Film & physische Ausgabe',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText:
                    isBoxSet ? 'Boxset-Titel' : 'Titel',
                prefixIcon: Icon(
                  isBoxSet
                      ? Icons.all_inbox_rounded
                      : Icons.movie_outlined,
                ),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Bitte einen Titel eingeben.'
                      : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'Format / Verpackung',
                prefixIcon: Icon(Icons.album_outlined),
              ),
              items: CollectionItem.mediaFormats
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _format = value ?? _format;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _edition,
              decoration: InputDecoration(
                labelText: 'Edition',
                hintText: isBoxSet
                    ? 'z. B. Limited Edition'
                    : 'z. B. White Edition, Extended Edition',
                prefixIcon:
                    const Icon(Icons.auto_awesome_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ean,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'EAN / Barcode',
                helperText: isBoxSet
                    ? 'Optional. Boxsets ohne EAN bleiben trotzdem lokal speicherbar.'
                    : 'Optional. Kann bei Bedarf manuell eingetragen werden.',
                prefixIcon:
                    const Icon(Icons.qr_code_2_rounded),
              ),
            ),
            if (isBoxSet) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      'Enthaltene Filme (${_components.length})',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Film hinzufügen',
                    onPressed: _addBoxsetMovie,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_components.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.video_library_outlined,
                          size: 34,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Noch keine Filme zugeordnet.',
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _addBoxsetMovie,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Film hinzufügen'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(
                  _components.length,
                  (index) {
                    final component = _components[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 9),
                      child: Card(
                        child: ListTile(
                          leading: SizedBox(
                            width: 42,
                            height: 62,
                            child: MoviePoster(
                              url: component.posterUrl,
                              borderRadius: 7,
                            ),
                          ),
                          title: Text(
                            component.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: component.year == null
                              ? null
                              : Text('${component.year}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Nach oben',
                                onPressed: index == 0
                                    ? null
                                    : () => _moveBoxsetMovie(
                                          index,
                                          -1,
                                        ),
                                icon: const Icon(
                                  Icons.arrow_upward_rounded,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Nach unten',
                                onPressed:
                                    index == _components.length - 1
                                        ? null
                                        : () =>
                                            _moveBoxsetMovie(
                                              index,
                                              1,
                                            ),
                                icon: const Icon(
                                  Icons.arrow_downward_rounded,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Entfernen',
                                onPressed: () =>
                                    _removeBoxsetMovie(index),
                                icon: const Icon(
                                  Icons.close_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_components.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _addBoxsetMovie,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Weiteren Film hinzufügen',
                  ),
                ),
            ],
            const SizedBox(height: 22),
            _SectionTitle(
              _wishlist
                  ? 'Wunschdetails'
                  : isBoxSet
                      ? 'Dein Boxset'
                      : 'Deine Ausgabe',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: InputDecoration(
                labelText: _wishlist
                    ? 'Gewünschter Zustand'
                    : 'Zustand',
                prefixIcon:
                    const Icon(Icons.verified_outlined),
              ),
              items: CollectionItem.conditions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _condition = value ?? _condition,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _wishlist
                    ? 'Preisvorstellung'
                    : 'Kaufpreis',
                hintText: 'z. B. 19,99',
                suffixText: '€',
                prefixIcon:
                    const Icon(Icons.euro_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                return _parsePrice() == null
                    ? 'Bitte eine gültige Zahl eingeben.'
                    : null;
              },
            ),
            if (!_wishlist) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchaseDate,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Kaufdatum',
                  hintText: 'Optional',
                  prefixIcon: const Icon(
                    Icons.calendar_today_outlined,
                  ),
                  suffixIcon: _purchaseDate.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(
                            () => _purchaseDate.clear(),
                          ),
                          icon:
                              const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Standort',
                  hintText:
                      'z. B. Wohnzimmer · Regal 2',
                  prefixIcon:
                      Icon(Icons.inventory_2_outlined),
                ),
              ),
            ],
            if (!isBoxSet) ...[
              const SizedBox(height: 18),
              _SectionTitle('Meine Bewertung'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    12,
                  ),
                  child: _userRating == null
                      ? Row(
                          children: [
                            const Icon(
                              Icons.star_border_rounded,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Noch nicht bewertet',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Deine persönliche Wertung ist unabhängig von IMDb und TMDB.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.tonal(
                              onPressed: () => setState(
                                () => _userRating = 7.0,
                              ),
                              child: const Text('Bewerten'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFE7B95E),
                                  size: 30,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${_formatUserRating(_userRating!)} / 10',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _userRating = null,
                                  ),
                                  child:
                                      const Text('Entfernen'),
                                ),
                              ],
                            ),
                            Slider(
                              value: _userRating!,
                              min: 0.5,
                              max: 10,
                              divisions: 19,
                              label:
                                  _formatUserRating(_userRating!),
                              onChanged: (value) => setState(
                                () => _userRating = value,
                              ),
                            ),
                            Text(
                              '0,5 bis 10 Punkte · Schritte von 0,5',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: SwitchListTile(
                value: _favorite,
                onChanged: (value) =>
                    setState(() => _favorite = value),
                secondary: const Icon(
                  Icons.favorite_outline_rounded,
                ),
                title: const Text(
                  'Favorit',
                  style:
                      TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle:
                    const Text('Eintrag hervorheben'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_primaryActionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: 19),
    );
  }
}
