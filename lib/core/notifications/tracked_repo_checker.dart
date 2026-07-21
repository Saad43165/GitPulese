import '../../data/local/database_helper.dart';
import '../../data/local/tracked_repos_table.dart';
import '../../data/remote/github_api_service.dart';
import '../network/dio_client.dart';
import '../notifications/notification_service.dart';

/// Runs a real check against the GitHub API for every tracked repo:
/// fetches the latest release, compares it to what was last seen, and
/// fires a real local notification if it's new. This is the same logic
/// whether triggered by the manual "Check now" button or a background task.
class TrackedRepoChecker {
  TrackedRepoChecker._();

  static Future<int> checkAllTrackedRepos() async {
    final db = await DatabaseHelper.instance.database;
    final tracked = await TrackedReposTable.getAllTracked(db);
    if (tracked.isEmpty) return 0;

    final api = GitHubApiService(DioClient.instance.client);
    int newEventsFound = 0;

    for (final row in tracked) {
      final repoId = row['repoId'] as int;
      final fullName = row['fullName'] as String;
      final lastKnownTag = row['lastKnownReleaseTag'] as String?;
      final parts = fullName.split('/');
      if (parts.length != 2) continue;

      try {
        final releases = await api.getRepoReleases(parts[0], parts[1], perPage: 1);
        if (releases.isNotEmpty) {
          final latest = releases.first as Map<String, dynamic>;
          final latestTag = latest['tag_name'] as String?;

          if (latestTag != null && latestTag != lastKnownTag) {
            if (lastKnownTag != null) {
              // Only notify if this isn't the first-ever check (avoids a
              // notification storm the moment someone tracks a repo).
              await NotificationService.instance.showNewReleaseNotification(
                repoId: repoId,
                repoFullName: fullName,
                tag: latestTag,
              );
              newEventsFound++;
            }
            await TrackedReposTable.updateLastKnownRelease(db, repoId, latestTag);
          }
        }
      } on GitHubApiException catch (e) {
        if (e.statusCode != 404) {
          rethrow;
        }
        continue;
      } catch (_) {
        // Skip this repo's check on error rather than aborting the whole batch.
        continue;
      }
    }

    return newEventsFound;
  }
}
