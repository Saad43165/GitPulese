import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications/background_task_manager.dart';
import '../core/notifications/tracked_repo_checker.dart';
import '../data/local/tracked_repos_table.dart';
import '../data/models/repo_model.dart';
import 'core_providers.dart';
import 'settings_providers.dart';
import '../data/remote/github_api_service.dart';
import '../core/network/dio_client.dart' show GitHubApiException;

final trackedReposProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final helper = ref.watch(databaseHelperProvider);
  final db = await helper.database;
  return TrackedReposTable.getAllTracked(db);
});

final isTrackedProvider = FutureProvider.autoDispose.family<bool, int>((ref, repoId) async {
  final helper = ref.watch(databaseHelperProvider);
  final db = await helper.database;
  return TrackedReposTable.isTracked(db, repoId);
});

class TrackingActions {
  TrackingActions(this.ref);
  final Ref ref;

  Future<void> toggle(GhRepo repo) async {
    final helper = ref.read(databaseHelperProvider);
    final db = await helper.database;
    final tracked = await TrackedReposTable.isTracked(db, repo.id);

    if (tracked) {
      await TrackedReposTable.untrack(db, repo.id);
    } else {
      await TrackedReposTable.track(db, repoId: repo.id, fullName: repo.fullName);
      // Baseline the current latest release immediately so the first
      // background/manual check doesn't fire a notification for a release
      // that already existed before tracking started.
      final api = ref.read(githubApiServiceProvider);
      try {
        final releases = await api.getRepoReleases(repo.owner.login, repo.name, perPage: 1);
        if (releases.isNotEmpty) {
          final tag = (releases.first as Map<String, dynamic>)['tag_name'] as String?;
          await TrackedReposTable.updateLastKnownRelease(db, repo.id, tag);
        }
      } on GitHubApiException catch (e) {
        if (e.statusCode != 404) {
          rethrow;
        }
      } catch (_) {
        // Non-fatal — first real check will just pick up the baseline then.
      }
    }

    ref.invalidate(isTrackedProvider(repo.id));
    ref.invalidate(trackedReposProvider);
  }
}

final trackingActionsProvider = Provider((ref) => TrackingActions(ref));

/// Runs a real, immediate check against GitHub for every tracked repo.
final manualCheckResultProvider = FutureProvider.autoDispose<int>((ref) async {
  return TrackedRepoChecker.checkAllTrackedRepos();
});

class BackgroundCheckToggler {
  BackgroundCheckToggler(this.ref);
  final Ref ref;

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await BackgroundTaskManager.schedulePeriodicCheck();
    } else {
      await BackgroundTaskManager.cancelPeriodicCheck();
    }
    await ref.read(backgroundChecksEnabledProvider.notifier).setEnabled(enabled);
  }
}

final backgroundCheckTogglerProvider = Provider((ref) => BackgroundCheckToggler(ref));

final trackedReleasesFeedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final tracked = await ref.watch(trackedReposProvider.future);
  if (tracked.isEmpty) return [];

  final api = ref.watch(githubApiServiceProvider);
  final allReleases = <Map<String, dynamic>>[];

  final futures = tracked.map((item) async {
    final fullName = item['fullName'] as String;
    final parts = fullName.split('/');
    if (parts.length != 2) return;

    try {
      final releases = await api.getRepoReleases(parts[0], parts[1], perPage: 5);
      for (final r in releases) {
        if (r is Map<String, dynamic>) {
          final copy = Map<String, dynamic>.from(r);
          copy['repoFullName'] = fullName;
          allReleases.add(copy);
        }
      }
    } on GitHubApiException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
    } catch (_) {
      // Fail silently for one repository to keep the rest working
    }
  });

  await Future.wait(futures);

  allReleases.sort((a, b) {
    final aDate = DateTime.tryParse(a['published_at'] as String? ?? '') ?? DateTime(0);
    final bDate = DateTime.tryParse(b['published_at'] as String? ?? '') ?? DateTime(0);
    return bDate.compareTo(aDate);
  });

  return allReleases;
});
