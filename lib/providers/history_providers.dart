import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/history_entry.dart';
import '../data/models/repo_model.dart';
import 'core_providers.dart';

final historyListProvider =
    FutureProvider.autoDispose<List<HistoryEntry>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  final rows = await db.getHistory();
  return rows.map((r) => HistoryEntry.fromMap(r)).toList();
});

class HistoryActions {
  HistoryActions(this.ref);
  final Ref ref;

  Future<void> logSearch({
    required String type, // search_repo, search_code, search_user, search_issue
    required String query,
    String? subtitle,
  }) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertHistory({
      'type': type,
      'query': query,
      'subtitle': subtitle,
      'avatarUrl': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    ref.invalidate(historyListProvider);
  }

  Future<void> logViewed({
    required String type, // viewed_repo, viewed_user
    required String name,
    String? subtitle,
    String? avatarUrl,
  }) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertHistory({
      'type': type,
      'query': name,
      'subtitle': subtitle,
      'avatarUrl': avatarUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    ref.invalidate(historyListProvider);
  }

  Future<void> deleteEntry(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteHistoryEntry(id);
    ref.invalidate(historyListProvider);
  }

  Future<void> clearAll() async {
    final db = ref.read(databaseHelperProvider);
    await db.clearHistory();
    ref.invalidate(historyListProvider);
  }

  Future<void> clearBookmarks() async {
    final db = ref.read(databaseHelperProvider);
    await db.clearBookmarks();
    ref.invalidate(bookmarksProvider);
  }
}

final historyActionsProvider = Provider((ref) => HistoryActions(ref));

// ---- Bookmarks ----

final bookmarksProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getBookmarks();
});

final isBookmarkedProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, repoId) async {
  final db = ref.watch(databaseHelperProvider);
  return db.isBookmarked(repoId);
});

class BookmarkActions {
  BookmarkActions(this.ref);
  final Ref ref;

  Future<void> toggle(GhRepo repo) async {
    final db = ref.read(databaseHelperProvider);
    final isSaved = await db.isBookmarked(repo.id);
    if (isSaved) {
      await db.removeBookmark(repo.id);
    } else {
      await db.addBookmark({
        'repoId': repo.id,
        'fullName': repo.fullName,
        'ownerLogin': repo.owner.login,
        'avatarUrl': repo.owner.avatarUrl,
        'description': repo.description,
        'language': repo.language,
        'stars': repo.stargazersCount,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    ref.invalidate(isBookmarkedProvider(repo.id));
    ref.invalidate(bookmarksProvider);
  }

  Future<void> clearAll() async {
    final db = ref.read(databaseHelperProvider);
    await db.clearBookmarks();
    ref.invalidate(bookmarksProvider);
  }
}

final bookmarkActionsProvider = Provider((ref) => BookmarkActions(ref));
