import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final prefs = await SharedPreferences.getInstance();
  DioClient.instance.applyPat(prefs.getString(ApiConstants.patStorageKey));

  await NotificationService.instance.init();
  await BackgroundTaskManager.initialize();

  runApp(const ProviderScope(child: GitPulseApp()));
}
