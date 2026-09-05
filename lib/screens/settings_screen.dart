import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _loadedInitialValues = false;

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

  Future<void> _copyBackup() async {
    final json = AppStateScope.of(context).createBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup wurde in die Zwischenablage kopiert.')),
    );
  }

  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('In der Zwischenablage wurde kein Backup gefunden.')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wiederherstellen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await AppStateScope.of(context).restoreBackupJson(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count Filme wurden wiederhergestellt.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup konnte nicht gelesen werden: $error')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Alles löschen')),
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
          Text('Filmdaten', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TMDB',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ReelShelf nutzt TMDB für Cover, Beschreibungen, Laufzeiten und weitere Filmdaten. Der Token ist kostenlos und wird nur lokal auf deinem Gerät gespeichert.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _token,
                    obscureText: _obscureToken,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'TMDB Read Access Token',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscureToken = !_obscureToken),
                        icon: Icon(
                          _obscureToken ? Icons.visibility_rounded : Icons.visibility_off_rounded,
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
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            hintText: 'DE',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveTmdb,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('TMDB speichern'),
                  ),
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
          Text('Backup & Daten', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text('Backup kopieren', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${state.items.length} Einträge als JSON in die Zwischenablage'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _copyBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_rounded),
                  title: const Text('Backup einfügen', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('JSON-Backup aus der Zwischenablage wiederherstellen'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _restoreBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Demo-Sammlung laden', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Nur verfügbar, wenn die Sammlung leer ist'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: state.items.isEmpty,
                  onTap: state.items.isEmpty
                      ? () async {
                          await state.seedDemoData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Demo-Sammlung wurde angelegt.')),
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
          Text('Über ReelShelf', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.movie_filter_rounded),
                  title: Text('ReelShelf 0.1.0', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Moderne Sammlung für physische Filme'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Open-Source-Lizenzen'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'ReelShelf',
                    applicationVersion: '0.1.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'This product uses the TMDB API but is not endorsed or certified by TMDB.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
