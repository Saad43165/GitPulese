import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'tracked_repo_checker.dart';
import 'github_notification_sync.dart';

const String kTrackedReposCheckTask = 'tracked_repos_check_task';
const String kGitHubNotificationsTask = 'github_notifications_sync_task';

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
      } catch (_) {}
    }
    if (task == kGitHubNotificationsTask) {
      try {
        await GitHubNotificationSync.run();
      } catch (_) {}
    }
    return true;
  });
}

class BackgroundTaskManager {
  BackgroundTaskManager._();

  static Future<void> initialize() async {
    await Workmanager().initialize(backgroundTaskDispatcher);
  }

  /// Syncs daily trending repo & stars telemetry to native home widgets.
  static Future<void> updateHomeWidgetData({required String repoName, required String starsCount}) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_repo_title', repoName);
      await HomeWidget.saveWidgetData<String>('widget_stars_count', starsCount);
      await HomeWidget.updateWidget(
        name: 'GitPulseHomeWidget',
        iOSName: 'GitPulseHomeWidget',
      );
    } catch (_) {}
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

  /// Polls GitHub notifications every 15 minutes (Android minimum).
  /// Shows local push notifications for new unread items.
  static Future<void> scheduleGitHubNotificationSync() async {
    await Workmanager().registerPeriodicTask(
      kGitHubNotificationsTask,
      kGitHubNotificationsTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelGitHubNotificationSync() async {
    await Workmanager().cancelByUniqueName(kGitHubNotificationsTask);
  }
}
