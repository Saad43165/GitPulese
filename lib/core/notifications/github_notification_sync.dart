import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../navigation/deep_link_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kLastSeenKey = 'gh_notif_last_seen';
const _kEnabledKey = 'gh_notif_push_enabled';

/// Polls GitHub /notifications since the last check and fires local
/// notifications for any new unread items. Designed to run both
/// in-process and from the Workmanager background isolate.
class GitHubNotificationSync {
  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabledKey) ?? true;
    if (!enabled) return;

    const secureStorage = FlutterSecureStorage();
    final token = await secureStorage.read(key: ApiConstants.patStorageKey);
    if (token == null || token.isEmpty) return;

    final lastSeen = prefs.getString(_kLastSeenKey);
    final now = DateTime.now().toUtc();

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.github.com',
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final queryParams = <String, dynamic>{'per_page': 20};
      if (lastSeen != null) queryParams['since'] = lastSeen;

      final response = await dio.get('/notifications', queryParameters: queryParams);
      if (response.statusCode == 304) return; // nothing new

      final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      if (items.isEmpty) {
        await prefs.setString(_kLastSeenKey, now.toIso8601String());
        return;
      }

      await _showNotifications(items);
      await prefs.setString(_kLastSeenKey, now.toIso8601String());
    } catch (_) {
      // Background task — swallow errors silently.
    }
  }

  static Future<void> _showNotifications(List<Map<String, dynamic>> items) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        DeepLinkHandler.handleNotificationPayload(response.payload);
      },
    );

    const channel = AndroidNotificationDetails(
      'github_notifications',
      'GitHub Notifications',
      channelDescription: 'New GitHub activity notifications',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'github_notifs',
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: channel);

    // Summary notification for grouped display (Android 7+)
    if (items.length > 3) {
      final repoNames = items
          .map((n) => (n['repository'] as Map?)?['full_name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(3)
          .join(', ');
      await plugin.show(
        99999,
        'GitHub — ${items.length} new notifications',
        repoNames.isNotEmpty ? 'In: $repoNames…' : 'You have unread activity',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'github_notifications',
            'GitHub Notifications',
            channelDescription: 'New GitHub activity notifications',
            importance: Importance.high,
            priority: Priority.high,
            groupKey: 'github_notifs',
            setAsGroupSummary: true,
          ),
        ),
      );
    }

    for (var i = 0; i < items.length && i < 5; i++) {
      final item = items[i];
      final subject = item['subject'] as Map<String, dynamic>?;
      final repo = item['repository'] as Map<String, dynamic>?;
      final reason = item['reason'] as String? ?? '';
      final title = subject?['title'] as String? ?? 'New notification';
      final type = subject?['type'] as String? ?? '';
      final repoFullName = repo?['full_name'] as String? ?? '';
      final subjectUrl = subject?['url'] as String? ?? '';

      final body = _reasonLabel(reason, type, repoFullName);
      // Use stable hash of notification id string to avoid int overflow.
      final notifId = item['id'].toString().hashCode.abs() % 99990;

      final payload = subjectUrl.isNotEmpty && repoFullName.isNotEmpty
          ? DeepLinkHandler.buildPayload(
              subjectUrl: subjectUrl,
              type: type,
              repoFullName: repoFullName,
              title: title,
            )
          : null;

      await plugin.show(notifId, title, body, details, payload: payload);
    }
  }

  static String _reasonLabel(String reason, String type, String repoName) {
    final prefix = repoName.isNotEmpty ? '$repoName · ' : '';
    return switch (reason) {
      'mention' => '${prefix}You were mentioned',
      'review_requested' => '${prefix}Review requested',
      'assign' => '${prefix}You were assigned',
      'author' => '${prefix}Activity on your $type',
      'comment' => '${prefix}New comment on $type',
      'ci_activity' => '${prefix}CI run completed',
      'subscribed' => '${prefix}New activity on $type',
      'team_mention' => '${prefix}Your team was mentioned',
      _ => '${prefix}New activity',
    };
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? true;
  }
}
