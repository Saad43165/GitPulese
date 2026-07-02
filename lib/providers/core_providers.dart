import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../data/local/database_helper.dart';
import '../data/remote/github_api_service.dart';

/// Singleton GitHub API service, backed by the real dio client.
final githubApiServiceProvider = Provider<GitHubApiService>((ref) {
  return GitHubApiService(DioClient.instance.client);
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Theme mode (persisted to SharedPreferences for real, across app restarts).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'light') {
      state = ThemeMode.light;
    } else if (value == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Live rate-limit info, updated after every real API response.
class RateLimitState {
  final int? limit;
  final int? remaining;
  final DateTime? resetAt;
  const RateLimitState({this.limit, this.remaining, this.resetAt});
}

class RateLimitWatcher extends StateNotifier<RateLimitState> {
  RateLimitWatcher() : super(const RateLimitState()) {
    RateLimitNotifier.instance.addListener(_onUpdate);
    final latest = RateLimitNotifier.instance.latest;
    if (latest != null) _onUpdate(latest);
  }

  void _onUpdate(RateLimitInfo info) {
    state = RateLimitState(
      limit: info.limit,
      remaining: info.remaining,
      resetAt: info.resetAt,
    );
  }

  @override
  void dispose() {
    RateLimitNotifier.instance.removeListener(_onUpdate);
    super.dispose();
  }
}

final rateLimitProvider =
    StateNotifierProvider<RateLimitWatcher, RateLimitState>((ref) => RateLimitWatcher());
