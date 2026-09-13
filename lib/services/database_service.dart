import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/collection_item.dart';
import '../models/physical_release.dart';
import '../models/release_component.dart';

class DatabaseService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final root = await getDatabasesPath();
    final path = p.join(root, 'reelshelf.db');

    _database = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createReleaseTables(db);
        await _createCollectionTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createReleaseTables(db);

          await db.execute(
            'ALTER TABLE collection_items ADD COLUMN release_id INTEGER REFERENCES physical_releases(id) ON DELETE SET NULL',
          );

          await db.execute('''
            INSERT OR IGNORE INTO physical_releases (
              ean,
              tmdb_id,
              title,
              media_format,
              edition,
              release_type,
              region,
              packaging,
              publisher,
              cover_url,
              created_at,
              updated_at
            )
            SELECT
              UPPER(REPLACE(REPLACE(REPLACE(TRIM(ean), ' ', ''), '-', ''), '.', '')),
              tmdb_id,
              title,
              media_format,
              edition,
              CASE WHEN media_format = 'Boxset' THEN 'boxset' ELSE 'single' END,
              'DE',
              '',
              '',
              NULL,
              created_at,
              updated_at
            FROM collection_items
            WHERE TRIM(ean) <> ''
          ''');

          await db.execute('''
            UPDATE collection_items
            SET release_id = (
              SELECT physical_releases.id
              FROM physical_releases
              WHERE physical_releases.ean =
                UPPER(REPLACE(REPLACE(REPLACE(TRIM(collection_items.ean), ' ', ''), '-', ''), '.', ''))
              LIMIT 1
            )
            WHERE TRIM(ean) <> ''
          ''');
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE release_components ADD COLUMN year INTEGER',
          );
          await db.execute(
            'ALTER TABLE release_components ADD COLUMN poster_path TEXT',
          );
        }
      },
    );

    return _database!;
  }

  Future<void> _createReleaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS physical_releases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ean TEXT NOT NULL UNIQUE,
        tmdb_id INTEGER,
        title TEXT NOT NULL DEFAULT '',
        media_format TEXT NOT NULL DEFAULT 'Blu-ray',
        edition TEXT NOT NULL DEFAULT '',
        release_type TEXT NOT NULL DEFAULT 'single',
        region TEXT NOT NULL DEFAULT 'DE',
        packaging TEXT NOT NULL DEFAULT '',
        publisher TEXT NOT NULL DEFAULT '',
        cover_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_physical_releases_ean ON physical_releases(ean)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_physical_releases_tmdb ON physical_releases(tmdb_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS release_components (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        release_id INTEGER NOT NULL,
        tmdb_id INTEGER,
        title TEXT NOT NULL,
        year INTEGER,
        poster_path TEXT,
        sequence_number INTEGER,
        FOREIGN KEY (release_id)
          REFERENCES physical_releases(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_release_components_release ON release_components(release_id)',
    );
  }

  Future<void> _createCollectionTable(Database db) async {
    await db.execute('''
      CREATE TABLE collection_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        release_id INTEGER,
        tmdb_id INTEGER,
        title TEXT NOT NULL,
        original_title TEXT,
        year INTEGER,
        release_date TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        overview TEXT,
        runtime INTEGER,
        genres TEXT NOT NULL DEFAULT '',
        vote_average REAL,
        original_language TEXT,
        media_format TEXT NOT NULL DEFAULT 'Blu-ray',
        edition TEXT NOT NULL DEFAULT '',
        ean TEXT NOT NULL DEFAULT '',
        purchase_price REAL,
        purchase_date TEXT,
        condition TEXT NOT NULL DEFAULT 'Sehr gut',
        location TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        favorite INTEGER NOT NULL DEFAULT 0,
        wishlist INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (release_id)
          REFERENCES physical_releases(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_collection_title ON collection_items(title)',
    );
    await db.execute(
      'CREATE INDEX idx_collection_ean ON collection_items(ean)',
    );
    await db.execute(
      'CREATE INDEX idx_collection_wishlist ON collection_items(wishlist)',
    );
    await db.execute(
      'CREATE INDEX idx_collection_release ON collection_items(release_id)',
    );
  }

  Future<List<CollectionItem>> getAll() async {
    final db = await database;
    final rows = await db.query(
      'collection_items',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(CollectionItem.fromDbMap).toList();
  }

  Future<CollectionItem> insert(CollectionItem item) async {
    final db = await database;
    final map = item.toDbMap()..remove('id');
    final id = await db.insert('collection_items', map);
    return item.copyWith(id: id);
  }

  Future<void> update(CollectionItem item) async {
    if (item.id == null) {
      throw ArgumentError('Cannot update an item without an id.');
    }

    final db = await database;
    final map = item.toDbMap()..remove('id');
    await db.update(
      'collection_items',
      map,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(
      'collection_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('collection_items');
  }

  Future<List<PhysicalRelease>> getPhysicalReleases() async {
    final db = await database;
    final rows = await db.query(
      'physical_releases',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(PhysicalRelease.fromDbMap).toList();
  }

  Future<PhysicalRelease?> findPhysicalReleaseByEan(
    String barcode,
  ) async {
    final normalized = PhysicalRelease.normalizeBarcode(barcode);
    if (normalized.isEmpty) return null;

    final db = await database;
    final rows = await db.query(
      'physical_releases',
      where: 'ean = ?',
      whereArgs: [normalized],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PhysicalRelease.fromDbMap(rows.first);
  }

  Future<PhysicalRelease?> getPhysicalReleaseById(int id) async {
    final db = await database;
    final rows = await db.query(
      'physical_releases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PhysicalRelease.fromDbMap(rows.first);
  }

  Future<PhysicalRelease> savePhysicalRelease(
    PhysicalRelease release,
  ) async {
    final db = await database;
    final now = DateTime.now();

    if (release.id != null) {
      final existing = await getPhysicalReleaseById(release.id!);
      if (existing != null) {
        final updated = release.copyWith(
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        final map = updated.toDbMap()..remove('id');

        await db.update(
          'physical_releases',
          map,
          where: 'id = ?',
          whereArgs: [release.id],
        );
        return updated;
      }
    }

    final normalized = release.ean.startsWith('LOCALBOX-')
        ? release.ean
        : PhysicalRelease.normalizeBarcode(release.ean);

    if (normalized.isEmpty) {
      throw ArgumentError('A physical release needs a storage key.');
    }

    final existing = await findPhysicalReleaseByEan(normalized);

    if (existing == null) {
      final insertable = release.copyWith(
        ean: normalized,
        updatedAt: now,
      );
      final map = insertable.toDbMap()..remove('id');
      final id = await db.insert('physical_releases', map);
      return insertable.copyWith(id: id);
    }

    final updated = PhysicalRelease(
      id: existing.id,
      ean: normalized,
      tmdbId: release.tmdbId ?? existing.tmdbId,
      title: release.title.trim().isEmpty
          ? existing.title
          : release.title.trim(),
      mediaFormat: release.mediaFormat.trim().isEmpty
          ? existing.mediaFormat
          : release.mediaFormat.trim(),
      edition: release.edition.trim().isEmpty
          ? existing.edition
          : release.edition.trim(),
      releaseType: release.releaseType,
      region: release.region.trim().isEmpty
          ? existing.region
          : release.region.trim(),
      packaging: release.packaging.trim().isEmpty
          ? existing.packaging
          : release.packaging.trim(),
      publisher: release.publisher.trim().isEmpty
          ? existing.publisher
          : release.publisher.trim(),
      coverUrl: release.coverUrl ?? existing.coverUrl,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    final map = updated.toDbMap()..remove('id');
    await db.update(
      'physical_releases',
      map,
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return updated;
  }

  Future<List<ReleaseComponent>> getAllReleaseComponents() async {
    final db = await database;
    final rows = await db.query(
      'release_components',
      orderBy: 'release_id ASC, sequence_number ASC, id ASC',
    );
    return rows.map(ReleaseComponent.fromDbMap).toList();
  }

  Future<void> replaceReleaseComponents(
    int releaseId,
    List<ReleaseComponent> components,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'release_components',
        where: 'release_id = ?',
        whereArgs: [releaseId],
      );

      for (var index = 0; index < components.length; index++) {
        final component = components[index].copyWith(
          id: null,
          releaseId: releaseId,
          sequenceNumber: index,
        );
        final map = component.toDbMap()..remove('id');
        await txn.insert('release_components', map);
      }
    });
  }

  Future<void> clearPhysicalReleases() async {
    final db = await database;
    await db.delete('physical_releases');
  }
}
