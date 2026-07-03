import 'package:sqflite/sqflite.dart';

/// Extends the existing DatabaseHelper with a "tracked_repos" table —
/// repos the user wants notified about when a new release or advisory
/// appears. This runs real queries against the same real sqflite database
/// already used for history/bookmarks.
class TrackedReposTable {
  TrackedReposTable._();
  static const String tableName = 'tracked_repos';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repoId INTEGER NOT NULL UNIQUE,
        fullName TEXT NOT NULL,
        lastKnownReleaseTag TEXT,
        lastCheckedAt INTEGER,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> track(Database db, {required int repoId, required String fullName}) async {
    await db.insert(
      tableName,
      {
        'repoId': repoId,
        'fullName': fullName,
        'lastKnownReleaseTag': null,
        'lastCheckedAt': null,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> untrack(Database db, int repoId) async {
    await db.delete(tableName, where: 'repoId = ?', whereArgs: [repoId]);
  }

  static Future<bool> isTracked(Database db, int repoId) async {
    final rows = await db.query(tableName, where: 'repoId = ?', whereArgs: [repoId], limit: 1);
    return rows.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getAllTracked(Database db) async {
    return db.query(tableName, orderBy: 'addedAt DESC');
  }

  static Future<void> updateLastKnownRelease(Database db, int repoId, String? tag) async {
    await db.update(
      tableName,
      {'lastKnownReleaseTag': tag, 'lastCheckedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'repoId = ?',
      whereArgs: [repoId],
    );
  }
}
