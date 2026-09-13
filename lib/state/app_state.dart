import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/collection_item.dart';
import '../models/physical_release.dart';
import '../models/release_component.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    DatabaseService? databaseService,
    SettingsService? settingsService,
  })  : _database = databaseService ?? DatabaseService(),
        _settings = settingsService ?? SettingsService();

  final DatabaseService _database;
  final SettingsService _settings;

  List<CollectionItem> _items = const [];
  List<PhysicalRelease> _physicalReleases = const [];
  Map<int, List<ReleaseComponent>> _componentsByRelease = const {};
  String _tmdbToken = '';
  String _language = 'de-DE';
  String _region = 'DE';
  bool _initialized = false;
  bool _busy = false;

  List<CollectionItem> get items => List.unmodifiable(_items);
  List<PhysicalRelease> get physicalReleases =>
      List.unmodifiable(_physicalReleases);
  int get physicalReleaseCount => _physicalReleases.length;
  String get tmdbToken => _tmdbToken;
  String get language => _language;
  String get region => _region;
  bool get initialized => _initialized;
  bool get busy => _busy;

  List<CollectionItem> get ownedItems =>
      _items.where((item) => !item.wishlist).toList(growable: false);

  List<CollectionItem> get wishlistItems =>
      _items.where((item) => item.wishlist).toList(growable: false);

  Future<void> initialize() async {
    _busy = true;
    notifyListeners();

    _tmdbToken = await _settings.getTmdbToken();
    _language = await _settings.getLanguage();
    _region = await _settings.getRegion();
    await _reloadLocalData();

    _busy = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _reloadLocalData() async {
    _items = await _database.getAll();
    _physicalReleases = await _database.getPhysicalReleases();

    final allComponents =
        await _database.getAllReleaseComponents();
    final grouped = <int, List<ReleaseComponent>>{};

    for (final component in allComponents) {
      grouped
          .putIfAbsent(component.releaseId, () => [])
          .add(component);
    }

    _componentsByRelease = grouped;
  }

  Future<void> refresh() async {
    await _reloadLocalData();
    notifyListeners();
  }

  PhysicalRelease? findReleaseByEan(String barcode) {
    final normalized = PhysicalRelease.normalizeBarcode(barcode);
    if (normalized.isEmpty) return null;

    for (final release in _physicalReleases) {
      if (!release.hasScannableEan) continue;
      if (PhysicalRelease.normalizeBarcode(release.ean) == normalized) {
        return release;
      }
    }
    return null;
  }

  List<ReleaseComponent> componentsForRelease(int releaseId) {
    return List.unmodifiable(
      _componentsByRelease[releaseId] ?? const [],
    );
  }

  Future<CollectionItem> _attachRememberedRelease(
    CollectionItem item,
  ) async {
    final normalized = PhysicalRelease.normalizeBarcode(item.ean);
    final isBoxSet = item.mediaFormat == 'Boxset';

    if (normalized.isEmpty && !isBoxSet && item.releaseId == null) {
      return item;
    }

    String storageEan = normalized;

    if (storageEan.isEmpty && isBoxSet) {
      if (item.releaseId != null) {
        final existing = _physicalReleases.where(
          (release) => release.id == item.releaseId,
        );
        if (existing.isNotEmpty) {
          storageEan = existing.first.ean;
        }
      }

      if (storageEan.isEmpty) {
        storageEan =
            'LOCALBOX-${DateTime.now().microsecondsSinceEpoch}';
      }
    } else if (storageEan.isEmpty && item.releaseId != null) {
      final existing = _physicalReleases.where(
        (release) => release.id == item.releaseId,
      );
      if (existing.isNotEmpty) {
        storageEan = existing.first.ean;
      }
    }

    final release = await _database.savePhysicalRelease(
      PhysicalRelease.fromCollectionItem(
        item.copyWith(ean: normalized),
        region: _region,
        storageEan: storageEan,
      ),
    );

    return item.copyWith(
      releaseId: release.id,
      ean: normalized,
    );
  }

  Future<CollectionItem> addItem(CollectionItem item) async {
    final now = DateTime.now();
    final prepared = await _attachRememberedRelease(
      item.copyWith(createdAt: now, updatedAt: now),
    );
    final saved = await _database.insert(prepared);
    await refresh();
    return saved;
  }

  Future<CollectionItem> updateItem(CollectionItem item) async {
    final prepared = await _attachRememberedRelease(
      item.copyWith(updatedAt: DateTime.now()),
    );
    await _database.update(prepared);
    await refresh();

    for (final current in _items) {
      if (current.id == prepared.id) return current;
    }
    return prepared;
  }

  Future<void> replaceReleaseComponents(
    int releaseId,
    List<ReleaseComponent> components,
  ) async {
    await _database.replaceReleaseComponents(
      releaseId,
      components,
    );
    await refresh();
  }

  Future<void> deleteItem(CollectionItem item) async {
    if (item.id == null) return;
    await _database.delete(item.id!);
    await refresh();
  }

  Future<void> saveTmdbSettings({
    required String token,
    required String language,
    required String region,
  }) async {
    _tmdbToken = token.trim();
    _language =
        language.trim().isEmpty ? 'de-DE' : language.trim();
    _region = region.trim().isEmpty
        ? 'DE'
        : region.trim().toUpperCase();

    await _settings.setTmdbToken(_tmdbToken);
    await _settings.setLanguage(_language);
    await _settings.setRegion(_region);
    notifyListeners();
  }

  String createBackupJson() {
    final components = _componentsByRelease.values
        .expand((entries) => entries)
        .map((component) => component.toDbMap())
        .toList();

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'ReelShelf',
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': _items.map((item) => item.toJson()).toList(),
      'physicalReleases':
          _physicalReleases.map((release) => release.toJson()).toList(),
      'releaseComponents': components,
    });
  }

  Future<int> restoreBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    final List<dynamic> rawItems;
    final List<dynamic> rawReleases;
    final List<dynamic> rawComponents;

    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      rawItems = decoded['items'] as List<dynamic>;
      rawReleases = decoded['physicalReleases'] is List
          ? decoded['physicalReleases'] as List<dynamic>
          : const [];
      rawComponents = decoded['releaseComponents'] is List
          ? decoded['releaseComponents'] as List<dynamic>
          : const [];
    } else if (decoded is List) {
      rawItems = decoded;
      rawReleases = const [];
      rawComponents = const [];
    } else {
      throw const FormatException(
        'Das Backup enthält keine Filmliste.',
      );
    }

    final parsedItems = rawItems
        .whereType<Map>()
        .map((entry) {
          final normalized = <String, dynamic>{};
          for (final mapEntry in entry.entries) {
            normalized[mapEntry.key.toString()] = mapEntry.value;
          }
          return CollectionItem.fromJson(normalized).withoutId();
        })
        .toList();

    final parsedReleases = rawReleases
        .whereType<Map>()
        .map((entry) {
          final normalized = <String, dynamic>{};
          for (final mapEntry in entry.entries) {
            normalized[mapEntry.key.toString()] = mapEntry.value;
          }
          return PhysicalRelease.fromJson(normalized);
        })
        .where((release) => release.ean.trim().isNotEmpty)
        .toList();

    await _database.clear();
    await _database.clearPhysicalReleases();

    final oldToNewReleaseId = <int, int>{};

    for (final release in parsedReleases) {
      final saved = await _database.savePhysicalRelease(
        release.copyWith(id: null),
      );
      if (release.id != null && saved.id != null) {
        oldToNewReleaseId[release.id!] = saved.id!;
      }
    }

    if (rawComponents.isNotEmpty) {
      final grouped = <int, List<ReleaseComponent>>{};

      for (final entry in rawComponents.whereType<Map>()) {
        final normalized = <String, Object?>{};
        for (final mapEntry in entry.entries) {
          normalized[mapEntry.key.toString()] = mapEntry.value;
        }

        final oldReleaseId =
            (normalized['release_id'] as num?)?.toInt();
        if (oldReleaseId == null) continue;

        final newReleaseId =
            oldToNewReleaseId[oldReleaseId];
        if (newReleaseId == null) continue;

        final component =
            ReleaseComponent.fromDbMap(normalized).copyWith(
          id: null,
          releaseId: newReleaseId,
        );

        grouped
            .putIfAbsent(newReleaseId, () => [])
            .add(component);
      }

      for (final entry in grouped.entries) {
        await _database.replaceReleaseComponents(
          entry.key,
          entry.value,
        );
      }
    }

    for (final item in parsedItems) {
      final rememberedReleaseId = item.releaseId == null
          ? null
          : oldToNewReleaseId[item.releaseId!];

      final restored = item.copyWith(
        releaseId: rememberedReleaseId,
      );

      final prepared = rememberedReleaseId != null
          ? restored
          : await _attachRememberedRelease(restored);

      await _database.insert(prepared);
    }

    await refresh();
    return parsedItems.length;
  }

  Future<void> clearCollection() async {
    await _database.clear();
    await refresh();
  }

  Future<void> clearLocalReleaseCache() async {
    await _database.clearPhysicalReleases();
    await refresh();
  }

  Future<void> seedDemoData() async {
    if (_items.isNotEmpty) return;

    final now = DateTime.now();
    final demos = [
      CollectionItem(
        title: 'Chihiros Reise ins Zauberland',
        originalTitle: '千と千尋の神隠し',
        year: 2001,
        runtime: 125,
        genres: 'Animation, Familie, Fantasy',
        mediaFormat: 'Blu-ray',
        edition: 'Studio Ghibli White Edition',
        condition: 'Sehr gut',
        favorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      CollectionItem(
        title: 'Der Herr der Ringe: Die Gefährten',
        year: 2001,
        runtime: 179,
        genres: 'Abenteuer, Fantasy',
        mediaFormat: '4K UHD',
        edition: 'Extended Edition',
        condition: 'Wie neu',
        location: 'Wohnzimmer · Regal 1',
        createdAt: now,
        updatedAt: now,
      ),
      CollectionItem(
        title: 'Blade Runner 2049',
        year: 2017,
        runtime: 164,
        genres: 'Science Fiction, Drama',
        mediaFormat: 'Steelbook',
        edition: '4K Steelbook',
        condition: 'Sehr gut',
        purchasePrice: 24.99,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final item in demos) {
      final prepared = await _attachRememberedRelease(item);
      await _database.insert(prepared);
    }
    await refresh();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree.');
    return scope!.notifier!;
  }
}
