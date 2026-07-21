import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'app.dart';
import 'core/constants/api_constants.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/background_task_manager.dart';
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('en', timeago.EnMessages());

  // Apply persisted GitHub PAT before any API call can fire.
  try {
    const secureStorage = FlutterSecureStorage();
    final token = await secureStorage.read(key: ApiConstants.patStorageKey);
    DioClient.instance.applyPat(token);
  } catch (_) {
    DioClient.instance.applyPat(null);
  }

  // Guard each init separately — a failure in one must NOT freeze the app.
  try {
    await NotificationService.instance.init();
  } catch (_) {}

  try {
    await BackgroundTaskManager.initialize();
  } catch (_) {}

  runApp(const ProviderScope(child: GitPulseApp()));
}
