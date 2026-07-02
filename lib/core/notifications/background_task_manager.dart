import 'package:workmanager/workmanager.dart';
import 'tracked_repo_checker.dart';

const String kTrackedReposCheckTask = 'tracked_repos_check_task';

/// This top-level function is the actual background entry point Workmanager
/// calls on Android. iOS background execution via Workmanager is far less
/// reliable (the OS decides when/if to run it) — treat iOS background
/// checks as best-effort only; the in-app "Check now" button is the
/// dependable path on both platforms.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kTrackedReposCheckTask) {
      try {
        await TrackedRepoChecker.checkAllTrackedRepos();
      } catch (_) {
        // Swallow errors in the background task — nothing to surface to.
      }
    }
    return true;
  });
}

class BackgroundTaskManager {
  BackgroundTaskManager._();

  static Future<void> initialize() async {
    await Workmanager().initialize(backgroundTaskDispatcher);
  }

  /// Registers a periodic check. Android enforces a minimum interval of
  /// 15 minutes for periodic tasks — requesting less will silently clamp
  /// to 15.
  static Future<void> schedulePeriodicCheck() async {
    await Workmanager().registerPeriodicTask(
      kTrackedReposCheckTask,
      kTrackedReposCheckTask,
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelPeriodicCheck() async {
    await Workmanager().cancelByUniqueName(kTrackedReposCheckTask);
  }
}
