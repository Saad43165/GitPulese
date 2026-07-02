import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'tracked_repos_table.dart';

/// Real, working local SQLite database. No mocked storage — every read/write
/// here goes to an actual on-device database file.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'gitexplorer.db';
  static const int _dbVersion = 2;

  static const String tableHistory = 'history';
  static const String tableBookmarks = 'bookmarks';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            query TEXT NOT NULL,
            subtitle TEXT,
            avatarUrl TEXT,
            timestamp INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableBookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            repoId INTEGER NOT NULL UNIQUE,
            fullName TEXT NOT NULL,
            ownerLogin TEXT NOT NULL,
            avatarUrl TEXT,
            description TEXT,
            language TEXT,
            stars INTEGER,
            savedAt INTEGER NOT NULL
          )
        ''');

        await db.execute(
            'CREATE INDEX idx_history_timestamp ON $tableHistory(timestamp)');

        await TrackedReposTable.createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await TrackedReposTable.createTable(db);
        }
      },
    );
  }

  // ----- History -----

  Future<int> insertHistory(Map<String, dynamic> entry) async {
    final db = await database;
    return db.insert(tableHistory, entry..remove('id'));
  }

  Future<List<Map<String, dynamic>>> getHistory({int limit = 200}) async {
    final db = await database;
    return db.query(tableHistory, orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> deleteHistoryEntry(int id) async {
    final db = await database;
    await db.delete(tableHistory, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete(tableHistory);
  }

  Future<void> clearHistoryByType(String typePrefix) async {
    final db = await database;
    await db.delete(tableHistory, where: 'type LIKE ?', whereArgs: ['$typePrefix%']);
  }

  // ----- Bookmarks -----

  Future<void> addBookmark(Map<String, dynamic> repo) async {
    final db = await database;
    await db.insert(
      tableBookmarks,
      repo,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeBookmark(int repoId) async {
    final db = await database;
    await db.delete(tableBookmarks, where: 'repoId = ?', whereArgs: [repoId]);
  }

  Future<bool> isBookmarked(int repoId) async {
    final db = await database;
    final result = await db.query(
      tableBookmarks,
      where: 'repoId = ?',
      whereArgs: [repoId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final db = await database;
    return db.query(tableBookmarks, orderBy: 'savedAt DESC');
  }

  Future<void> clearBookmarks() async {
    final db = await database;
    await db.delete(tableBookmarks);
  }
}
