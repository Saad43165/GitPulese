import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/dio_client.dart';
import '../providers/search_providers.dart';

/// Optional GitHub PAT — persisted locally, never sent anywhere except GitHub.
class GithubPatNotifier extends StateNotifier<String?> {
  GithubPatNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.patStorageKey);
    state = token;
    DioClient.instance.applyPat(token);
  }

  Future<void> save(String? token) async {
    final trimmed = token?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(ApiConstants.patStorageKey);
      state = null;
      DioClient.instance.applyPat(null);
    } else {
      await prefs.setString(ApiConstants.patStorageKey, trimmed);
      state = trimmed;
      DioClient.instance.applyPat(trimmed);
    }
  }

  bool get hasToken => state != null && state!.isNotEmpty;
}

final githubPatProvider =
    StateNotifierProvider<GithubPatNotifier, String?>((ref) => GithubPatNotifier());

final backgroundChecksEnabledProvider = StateNotifierProvider<BackgroundChecksNotifier, bool>(
  (ref) => BackgroundChecksNotifier(),
);

class BackgroundChecksNotifier extends StateNotifier<bool> {
  BackgroundChecksNotifier() : super(false) {
    _load();
  }

  static const _key = 'background_checks_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final defaultSearchTabProvider = StateNotifierProvider<DefaultSearchTabNotifier, SearchTab>(
  (ref) => DefaultSearchTabNotifier(),
);

class DefaultSearchTabNotifier extends StateNotifier<SearchTab> {
  DefaultSearchTabNotifier() : super(SearchTab.repositories) {
    _load();
  }

  static const _key = 'default_search_tab';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index != null && index >= 0 && index < SearchTab.values.length) {
      state = SearchTab.values[index];
    }
  }

  Future<void> setTab(SearchTab tab) async {
    state = tab;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, tab.index);
  }
}

final compactCardsProvider = StateNotifierProvider<CompactCardsNotifier, bool>(
  (ref) => CompactCardsNotifier(),
);

class CompactCardsNotifier extends StateNotifier<bool> {
  CompactCardsNotifier() : super(false) {
    _load();
  }

  static const _key = 'compact_cards';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setCompact(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
