import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/collection_item.dart';

class DatabaseService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    final path = p.join(root, 'reelshelf.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE collection_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_collection_title ON collection_items(title)');
        await db.execute('CREATE INDEX idx_collection_ean ON collection_items(ean)');
        await db.execute('CREATE INDEX idx_collection_wishlist ON collection_items(wishlist)');
      },
    );
    return _database!;
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
    await db.delete('collection_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('collection_items');
  }
}
