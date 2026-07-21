import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/dio_client.dart';
import '../data/models/user_and_search_models.dart';
import '../data/models/repo_model.dart';
import '../providers/core_providers.dart';
import '../providers/search_providers.dart';

/// Optional GitHub PAT — persisted securely, never sent anywhere except GitHub.
class GithubPatNotifier extends StateNotifier<String?> {
  final _secureStorage = const FlutterSecureStorage();

  GithubPatNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await _secureStorage.read(key: ApiConstants.patStorageKey);
      state = token;
      DioClient.instance.applyPat(token);
    } catch (_) {
      // Gracefully handle secure storage read failure
    }
  }

  Future<void> save(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _secureStorage.delete(key: ApiConstants.patStorageKey);
      state = null;
      DioClient.instance.applyPat(null);
    } else {
      await _secureStorage.write(key: ApiConstants.patStorageKey, value: trimmed);
      state = trimmed;
      DioClient.instance.applyPat(trimmed);
    }
  }

  bool get hasToken => state != null && state!.isNotEmpty;
}

final githubPatProvider =
    StateNotifierProvider<GithubPatNotifier, String?>((ref) => GithubPatNotifier());

/// Optional Groq API key — persisted securely. Used for all AI features.
/// Get a free key at https://console.groq.com (no credit card required).
class GroqApiKeyNotifier extends StateNotifier<String?> {
  final _secureStorage = const FlutterSecureStorage();
  static const _key = 'groq_api_key';

  GroqApiKeyNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final key = await _secureStorage.read(key: _key);
      state = key;
    } catch (_) {}
  }

  Future<void> save(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _secureStorage.delete(key: _key);
      state = null;
    } else {
      await _secureStorage.write(key: _key, value: trimmed);
      state = trimmed;
    }
  }

  bool get hasKey => state != null && state!.isNotEmpty;
}

final groqApiKeyProvider =
    StateNotifierProvider<GroqApiKeyNotifier, String?>((ref) => GroqApiKeyNotifier());


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

final demoUsernameProvider = StateProvider<String?>((ref) => null);

// ── Authenticated User ────────────────────────────────────────────────────────
/// Fetches the signed-in GitHub user profile (/user) whenever a PAT is stored.
/// Returns null when not authenticated. Auto-refreshes on sign-in/sign-out.
final authenticatedUserProvider = FutureProvider<GhUser?>((ref) async {
  final pat = ref.watch(githubPatProvider);
  final demoUser = ref.watch(demoUsernameProvider);
  final api = ref.read(githubApiServiceProvider);

  if (pat != null && pat.isNotEmpty) {
    try {
      return await api.getAuthenticatedUser();
    } catch (_) {
      // Fallback to demo user if authentication fails
    }
  }

  if (demoUser != null && demoUser.isNotEmpty) {
    try {
      return await api.getUserDetail(demoUser);
    } catch (_) {
      return null;
    }
  }

  return null;
});

final userReposProvider = FutureProvider.family<List<GhRepo>, String>((ref, username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserRepos(username);
});

final userDetailProvider = FutureProvider.autoDispose.family<GhUser, String>((ref, username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserDetail(username);
});


