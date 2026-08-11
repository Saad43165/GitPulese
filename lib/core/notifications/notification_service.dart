import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../navigation/deep_link_handler.dart';

/// Thin wrapper around flutter_local_notifications.
/// All notifications shown here are real system notifications.
/// Tapping a notification navigates to the correct screen via DeepLinkHandler.
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
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // Android 13+ requires runtime notification permission.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Handle tap on notification that launched the app from terminated state.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      // Delay so the navigator is ready.
      Future.delayed(const Duration(milliseconds: 800), () {
        DeepLinkHandler.handleNotificationPayload(payload);
      });
    }

    _initialized = true;
  }

  static void _onTap(NotificationResponse response) {
    DeepLinkHandler.handleNotificationPayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    // When tapped from background the isolate may be a fresh one;
    // DeepLinkHandler will no-op if navigatorKey has no context yet —
    // the launch-details path above covers the terminated-app case.
    DeepLinkHandler.handleNotificationPayload(response.payload);
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
    final payload = DeepLinkHandler.buildPayload(
      subjectUrl: 'https://api.github.com/repos/$repoFullName/releases',
      type: 'Release',
      repoFullName: repoFullName,
      title: 'New release: $tag',
    );
    await _plugin.show(
      repoId,
      'New release: $repoFullName',
      'Version $tag was just published.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
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
    final payload = DeepLinkHandler.buildPayload(
      subjectUrl: 'https://api.github.com/repos/$repoFullName/releases',
      type: 'Release',
      repoFullName: repoFullName,
      title: summary,
    );
    await _plugin.show(
      repoId + 1000000,
      'Security advisory: $repoFullName',
      summary,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
