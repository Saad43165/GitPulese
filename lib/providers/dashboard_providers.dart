import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/remote/github_api_service.dart';
import '../core/notifications/widget_manager.dart';
import 'core_providers.dart';

enum TrendingPeriod { daily, weekly, monthly }

final trendingPeriodProvider = StateProvider<TrendingPeriod>((ref) => TrendingPeriod.weekly);
final trendingLanguageProvider = StateProvider<String?>((ref) => null);

/// "Trending" isn't a real GitHub REST endpoint, so this builds a genuine
/// trending-style query using the actual search API: repos created/pushed
/// recently, sorted by stars. Every result is real, live data.
final trendingReposProvider =
    FutureProvider.autoDispose<SearchReposResult>((ref) async {
  final period = ref.watch(trendingPeriodProvider);
  final language = ref.watch(trendingLanguageProvider);
  final api = ref.watch(githubApiServiceProvider);

  final searchPeriod = switch (period) {
    TrendingPeriod.daily => SearchPeriod.today,
    TrendingPeriod.weekly => SearchPeriod.thisWeek,
    TrendingPeriod.monthly => SearchPeriod.thisMonth,
  };

  final result = await api.searchRepositories(
    query: '',
    language: language,
    minStars: 5,
    sort: RepoSort.stars,
    period: searchPeriod,
    perPage: 20,
  );

  if (result.items.isNotEmpty && period == TrendingPeriod.weekly) {
    WidgetManager.updateTrendingWidget(result.items.first);
  }

  return result;
});

/// Real top-by-followers user/org search using the GitHub Search Users API.
final topUsersProvider =
    FutureProvider.autoDispose<SearchUsersResult>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  final searchResult = await api.searchUsers(query: 'followers:>1000', type: 'user', perPage: 10);
  
  // Fetch detailed profiles to get the actual followers count
  final detailedUsers = await Future.wait(
    searchResult.items.map((user) => api.getUserDetail(user.login))
  );
  
  return SearchUsersResult(detailedUsers, searchResult.totalCount);
});

final topOrgsProvider =
    FutureProvider.autoDispose<SearchUsersResult>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.searchUsers(query: 'repos:>50', type: 'org');
});

/// All-time most-starred repos overall (a classic, real "top repos" list).
final allTimeTopReposProvider =
    FutureProvider.autoDispose<SearchReposResult>((ref) async {
  final language = ref.watch(trendingLanguageProvider);
  final api = ref.watch(githubApiServiceProvider);
  return api.searchRepositories(
    query: '',
    language: language,
    minStars: 1000,
    sort: RepoSort.stars,
    perPage: 20,
  );
});
