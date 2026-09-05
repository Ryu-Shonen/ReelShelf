import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        const SnackBar(content: Text('TMDB-Einstellungen gespeichert.')),
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
        _testMessage = 'Bitte zuerst einen TMDB Read Access Token eingeben.';
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
    final json = AppStateScope.of(context).createBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup wurde in die Zwischenablage kopiert.'),
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'In der Zwischenablage wurde kein Backup gefunden.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text(
          'Die aktuelle Sammlung wird ersetzt. Stelle sicher, dass du vorher ein Backup erstellt hast.',
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
        SnackBar(content: Text('$count Filme wurden wiederhergestellt.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup konnte nicht gelesen werden: $error'),
        ),
      );
    }
  }

  Future<void> _clearCollection() async {
    final state = AppStateScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sammlung komplett löschen?'),
        content: Text(
          'Alle ${state.items.length} Einträge werden dauerhaft von diesem Gerät entfernt.',
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
      const SnackBar(content: Text('Sammlung wurde gelöscht.')),
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
                    'ReelShelf nutzt TMDB für Cover, Beschreibungen, Laufzeiten und weitere Filmdaten. Der Token wird nur lokal auf deinem Gerät gespeichert.',
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
                              : const Icon(Icons.wifi_tethering_rounded),
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
                  const SizedBox(height: 12),
                  Text(
                    'Token erstellen: Auf themoviedb.org ein Konto anlegen und unter Einstellungen → API den „API Read Access Token“ kopieren.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
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
                    'Backup kopieren',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${state.items.length} Einträge als JSON in die Zwischenablage',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _copyBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.settings_backup_restore_rounded),
                  title: const Text(
                    'Backup einfügen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'JSON-Backup aus der Zwischenablage wiederherstellen',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
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
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: state.items.isEmpty,
                  onTap: state.items.isEmpty
                      ? () async {
                          await state.seedDemoData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Demo-Sammlung wurde angelegt.'),
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
            onPressed: state.items.isEmpty ? null : _clearCollection,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Gesamte Sammlung löschen'),
          ),
          const SizedBox(height: 26),
          Text(
            'Über ReelShelf',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.movie_filter_rounded),
                  title: Text(
                    'ReelShelf 0.2.0',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle:
                      Text('Moderne Sammlung für physische Filme'),
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
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Open-Source-Lizenzen'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'ReelShelf',
                    applicationVersion: '0.2.0',
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
