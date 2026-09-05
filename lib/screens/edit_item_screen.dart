import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'barcode_scanner_screen.dart';

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
  bool _saving = false;

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
          : item.purchasePrice!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _purchaseDate = TextEditingController(text: item.purchaseDate ?? '');
    _location = TextEditingController(text: item.location);
    _notes = TextEditingController(text: item.notes);
    _format = CollectionItem.mediaFormats.contains(item.mediaFormat)
        ? item.mediaFormat
        : 'Sonstiges';
    _condition = CollectionItem.conditions.contains(item.condition)
        ? item.condition
        : 'Sehr gut';
    _favorite = item.favorite;
    _wishlist = item.wishlist;
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

  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || result == null) return;
    _ean.text = result;
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_purchaseDate.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    _purchaseDate.text =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }

  double? _parsePrice() {
    final value = _price.text.trim().replaceAll(',', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final base = widget.item;
    final now = DateTime.now();
    final item = CollectionItem(
      id: base.id,
      tmdbId: base.tmdbId,
      title: _title.text.trim(),
      originalTitle: base.originalTitle,
      year: base.year,
      releaseDate: base.releaseDate,
      posterPath: base.posterPath,
      backdropPath: base.backdropPath,
      overview: base.overview,
      runtime: base.runtime,
      genres: base.genres,
      voteAverage: base.voteAverage,
      originalLanguage: base.originalLanguage,
      mediaFormat: _format,
      edition: _edition.text.trim(),
      ean: _ean.text.trim(),
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
      if (widget.isNew) {
        await state.addItem(item);
      } else {
        await state.updateItem(item);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Ausgabe hinzufügen' : 'Ausgabe bearbeiten'),
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
            if (item.posterUrl != null || item.title.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 108,
                        child: MoviePoster(url: item.posterUrl, borderRadius: 12),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title.isEmpty ? 'Manueller Eintrag' : item.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (item.year != null) '${item.year}',
                                  if (item.runtime != null) '${item.runtime} Min.',
                                ].join(' · '),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              if (item.genres.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  item.genres,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _SectionTitle('Film'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titel',
                prefixIcon: Icon(Icons.movie_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
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
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _format = value ?? _format),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _edition,
              decoration: const InputDecoration(
                labelText: 'Edition',
                hintText: 'z. B. White Edition, Extended Edition',
                prefixIcon: Icon(Icons.auto_awesome_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ean,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'EAN / Barcode',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Scannen',
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle('Deine Ausgabe'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(
                labelText: 'Zustand',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
              items: CollectionItem.conditions
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _condition = value ?? _condition),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Kaufpreis',
                hintText: 'z. B. 19,99',
                suffixText: '€',
                prefixIcon: Icon(Icons.euro_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return _parsePrice() == null ? 'Bitte eine gültige Zahl eingeben.' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseDate,
              readOnly: true,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Kaufdatum',
                hintText: 'Optional',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: _purchaseDate.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _purchaseDate.clear()),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Standort',
                hintText: 'z. B. Wohnzimmer · Regal 2',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
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
              child: Column(
                children: [
                  SwitchListTile(
                    value: _favorite,
                    onChanged: (value) => setState(() => _favorite = value),
                    secondary: const Icon(Icons.favorite_outline_rounded),
                    title: const Text('Favorit', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('In der Sammlung hervorheben'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _wishlist,
                    onChanged: (value) => setState(() => _wishlist = value),
                    secondary: const Icon(Icons.bookmark_outline_rounded),
                    title: const Text('Wunschliste', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      _wishlist
                          ? 'Noch nicht in deinem Besitz'
                          : 'Film zählt zu deiner Sammlung',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(widget.isNew ? 'Zur Sammlung hinzufügen' : 'Änderungen speichern'),
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
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
    );
  }
}
