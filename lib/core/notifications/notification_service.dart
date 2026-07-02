import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications. Every call here shows
/// a real system notification — nothing is simulated in-app.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Android 13+ requires runtime notification permission.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showNewReleaseNotification({
    required int repoId,
    required String repoFullName,
    required String tag,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'new_releases',
      'New Releases',
      channelDescription: 'Notifies when a tracked repo publishes a new release',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      repoId,
      'New release: $repoFullName',
      'Version $tag was just published.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> showAdvisoryNotification({
    required int repoId,
    required String repoFullName,
    required String summary,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'security_advisories',
      'Security Advisories',
      channelDescription: 'Notifies when a tracked repo has a new security advisory',
      importance: Importance.max,
      priority: Priority.max,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      repoId + 1000000, // offset so release + advisory ids for same repo don't collide
      'Security advisory: $repoFullName',
      summary,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
