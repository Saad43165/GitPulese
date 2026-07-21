import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages high-performance, scale-free local caching of repository files
/// on the device filesystem. Moves offline assets out of SharedPreferences XML
/// and onto direct file storage.
class VaultFileManager {
  VaultFileManager._();

  static Future<Directory> _getVaultDir(String owner, String repo) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(
      docsDir.path,
      'gitpulse_vault',
      owner.toLowerCase(),
      repo.toLowerCase(),
    ));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves the full recursive Git tree list in a compressed JSON schema.
  static Future<void> saveTree(
    String owner,
    String repo,
    List<dynamic> treeList,
  ) async {
    final dir = await _getVaultDir(owner, repo);
    final file = File(p.join(dir.path, 'tree.json'));
    await file.writeAsString(jsonEncode(treeList));
  }

  /// Loads the recursive Git tree list. Returns null if repository is not synced.
  static Future<List<dynamic>?> loadTree(String owner, String repo) async {
    try {
      final dir = await _getVaultDir(owner, repo);
      final file = File(p.join(dir.path, 'tree.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as List<dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Writes raw file contents to subfolders, matching their original repository path.
  static Future<void> saveFile(
    String owner,
    String repo,
    String filePath,
    String content,
  ) async {
    final dir = await _getVaultDir(owner, repo);
    final file = File(p.join(dir.path, 'files', filePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Reads raw file contents from the local documents structure.
  static Future<String?> loadFile(
    String owner,
    String repo,
    String filePath,
  ) async {
    try {
      final dir = await _getVaultDir(owner, repo);
      final file = File(p.join(dir.path, 'files', filePath));
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  /// Permanently purges a repository codebase and its structure from disk storage.
  static Future<void> deleteRepo(String owner, String repo) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(
        docsDir.path,
        'gitpulse_vault',
        owner.toLowerCase(),
        repo.toLowerCase(),
      ));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Performs offline regex or text-based search across all cached files in a repository.
  static Future<List<GrepSearchResult>> grepSearch({
    required String owner,
    required String repo,
    required String query,
    bool caseSensitive = false,
  }) async {
    final results = <GrepSearchResult>[];
    final tree = await loadTree(owner, repo);
    if (tree == null) return [];

    final q = caseSensitive ? query : query.toLowerCase();

    for (final item in tree) {
      if (item['type'] == 'blob') {
        final filePath = item['path'] as String;
        final content = await loadFile(owner, repo, filePath);
        if (content != null) {
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            final lineToCompare = caseSensitive ? line : line.toLowerCase();
            if (lineToCompare.contains(q)) {
              results.add(GrepSearchResult(
                owner: owner,
                repoName: repo,
                filePath: filePath,
                lineNumber: i + 1,
                lineContent: line.trim(),
              ));
            }
          }
        }
      }
    }
    return results;
  }
}

class GrepSearchResult {
  final String owner;
  final String repoName;
  final String filePath;
  final int lineNumber;
  final String lineContent;

  GrepSearchResult({
    required this.owner,
    required this.repoName,
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
  });
}
