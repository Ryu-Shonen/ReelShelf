import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../services/tmdb_service.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _token;
  late final TextEditingController _language;
  late final TextEditingController _region;
  bool _obscureToken = true;
  bool _saving = false;
  bool _testing = false;
  bool _loadedInitialValues = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController();
    _language = TextEditingController();
    _region = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInitialValues) return;
    final state = AppStateScope.of(context);
    _token.text = state.tmdbToken;
    _language.text = state.language;
    _region.text = state.region;
    _loadedInitialValues = true;
  }

  @override
  void dispose() {
    _token.dispose();
    _language.dispose();
    _region.dispose();
    super.dispose();
  }

  String get _normalizedLanguage =>
      _language.text.trim().isEmpty ? 'de-DE' : _language.text.trim();

  String get _normalizedRegion => _region.text.trim().isEmpty
      ? 'DE'
      : _region.text.trim().toUpperCase();

  Future<void> _saveTmdb() async {
    setState(() => _saving = true);
    try {
      await AppStateScope.of(context).saveTmdbSettings(
        token: _token.text,
        language: _language.text,
        region: _region.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TMDB-Einstellungen gespeichert.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testTmdb() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage =
            'Bitte zuerst einen TMDB Read Access Token eingeben.';
      });
      return;
    }

    setState(() {
      _testing = true;
      _testSuccess = null;
      _testMessage = null;
    });

    try {
      final service = TmdbService(
        token: token,
        language: _normalizedLanguage,
        region: _normalizedRegion,
      );
      await service.searchMovies('Avatar');
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _testMessage = 'Verbindung zu TMDB erfolgreich.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testMessage = 'Verbindung fehlgeschlagen: $error';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _copyBackup() async {
    final state = AppStateScope.of(context);
    final json = state.createBackupJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final now = DateTime.now();

    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = 'Unstreamed_Backup_$date.unstreamed';

    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Unstreamed-Backup speichern',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['unstreamed'],
      );

      if (!mounted || saved == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup gespeichert: $fileName',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    PlatformFile? file;

    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Unstreamed-Backup auswählen',
        type: FileType.custom,
        allowedExtensions: const ['unstreamed', 'reelshelf', 'json'],
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dateiauswahl fehlgeschlagen: $error',
          ),
        ),
      );
      return;
    }

    if (!mounted || file == null) return;

    String text;
    try {
      final bytes = await file.readAsBytes();
      text = utf8.decode(bytes).trim();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup-Datei konnte nicht gelesen werden: $error',
          ),
        ),
      );
      return;
    }

    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die gewählte Backup-Datei ist leer.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: Text(
          '„${file!.name}“ wird geladen. Die aktuelle Sammlung und die lokalen EAN-Zuordnungen werden ersetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final count =
          await AppStateScope.of(context).restoreBackupJson(text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count Filme aus „${file.name}“ wiederhergestellt.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup konnte nicht wiederhergestellt werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _refreshImdbRatings() async {
    final state = AppStateScope.of(context);

    await state.refreshImdbForCollection(
      forceDatasetRefresh: true,
    );

    if (!mounted) return;
    final message =
        state.imdbMessage ?? 'IMDb-Aktualisierung beendet.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _clearCollection() async {
    final state = AppStateScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sammlung komplett löschen?'),
        content: Text(
          'Alle ${state.items.length} Einträge werden vom Gerät entfernt. Gelernte EAN-Zuordnungen bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Alles löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.clearCollection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sammlung wurde gelöscht.'),
      ),
    );
  }

  Future<void> _clearReleaseCache() async {
    final state = AppStateScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EAN-Zuordnungen löschen?'),
        content: Text(
          '${state.physicalReleaseCount} lokal gelernte physische Ausgaben werden entfernt. Deine Filme in Sammlung und Wunschliste bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cache löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.clearLocalReleaseCache();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lokale EAN-Zuordnungen wurden gelöscht.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Filmdaten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TMDB',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unstreamed nutzt TMDB für Cover, Beschreibungen, Laufzeiten und weitere Filmdaten. Der Token wird nur lokal auf deinem Gerät gespeichert.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _token,
                    obscureText: _obscureToken,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) {
                      if (_testMessage != null) {
                        setState(() {
                          _testSuccess = null;
                          _testMessage = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'TMDB Read Access Token',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureToken = !_obscureToken,
                        ),
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _language,
                          decoration: const InputDecoration(
                            labelText: 'Sprache',
                            hintText: 'de-DE',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _region,
                          textCapitalization:
                              TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            hintText: 'DE',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _testing || _saving ? null : _testTmdb,
                          icon: _testing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.wifi_tethering_rounded,
                                ),
                          label: const Text('Testen'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _saving || _testing ? null : _saveTmdb,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Speichern'),
                        ),
                      ),
                    ],
                  ),
                  if (_testMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_testSuccess == true
                                ? Colors.green
                                : Colors.redAccent)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_testSuccess == true
                                  ? Colors.green
                                  : Colors.redAccent)
                              .withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testSuccess == true
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bewertungen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF5C518),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'IMDb',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Text(
                        '${state.imdbRatingCount} gespeichert',
                        style: TextStyle(
                          color:
                              Colors.white.withValues(alpha: 0.48),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Unstreamed lädt den offiziellen IMDb-Ratings-Datensatz direkt auf dein Gerät und speichert nur die Bewertungen deiner Filme lokal. Die Daten werden höchstens einmal pro 7 Tage automatisch erneuert.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      height: 1.45,
                    ),
                  ),
                  if (state.imdbMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.imdbMessage!,
                      style: TextStyle(
                        color:
                            Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed:
                        state.imdbBusy ? null : _refreshImdbRatings,
                    icon: state.imdbBusy
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      state.imdbBusy
                          ? 'IMDb wird aktualisiert …'
                          : 'IMDb-Bewertungen aktualisieren',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nur für persönliche, nicht-kommerzielle Nutzung. Information courtesy of IMDb (https://www.imdb.com). Used with permission.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Lokale Ausgabendaten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text(
                    'Gelernte EAN-Zuordnungen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${state.physicalReleaseCount} physische Ausgaben lokal gespeichert',
                  ),
                  trailing: const Icon(Icons.offline_pin_rounded),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text(
                    'So funktioniert es',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Unbekannte EAN einmal einem Film zuordnen. Danach erkennt Unstreamed diese Ausgabe lokal, ohne externe Produktdatenbank.',
                  ),
                ),
                if (state.physicalReleaseCount > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_sweep_outlined),
                    title: const Text(
                      'EAN-Cache leeren',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Sammlung und Wunschliste bleiben erhalten',
                    ),
                    trailing:
                        const Icon(Icons.chevron_right_rounded),
                    onTap: _clearReleaseCache,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Backup & Daten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text(
                    'Backup-Datei erstellen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${state.items.length} Einträge + ${state.physicalReleaseCount} EAN-Zuordnungen als .reelshelf-Datei speichern',
                  ),
                  trailing:
                      const Icon(Icons.chevron_right_rounded),
                  onTap: _copyBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.settings_backup_restore_rounded,
                  ),
                  title: const Text(
                    'Backup-Datei laden',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Gespeicherte .reelshelf- oder .json-Datei auswählen und wiederherstellen',
                  ),
                  trailing:
                      const Icon(Icons.chevron_right_rounded),
                  onTap: _restoreBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text(
                    'Demo-Sammlung laden',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Nur verfügbar, wenn die Sammlung leer ist',
                  ),
                  trailing:
                      const Icon(Icons.chevron_right_rounded),
                  enabled: state.items.isEmpty,
                  onTap: state.items.isEmpty
                      ? () async {
                          await state.seedDemoData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Demo-Sammlung wurde angelegt.',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed:
                state.items.isEmpty ? null : _clearCollection,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Gesamte Sammlung löschen'),
          ),
          const SizedBox(height: 26),
          Text(
            'Über Unstreamed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.movie_filter_rounded),
                  title: Text(
                    'Unstreamed 0.4.7',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Moderne Sammlung für physische Filme',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.data_object_rounded),
                  title: Text(
                    'Filmdaten von TMDB',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.offline_bolt_rounded),
                  title: Text(
                    'Physische Ausgaben lokal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'EAN-Zuordnungen und Boxset-Inhalte werden von Unstreamed auf deinem Gerät gespeichert. UPCitemdb wird nicht mehr abgefragt.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline_rounded),
                  title:
                      const Text('Open-Source-Lizenzen'),
                  trailing:
                      const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Unstreamed',
                    applicationVersion: '0.4.6',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
