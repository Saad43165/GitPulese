import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/remote/github_api_service.dart';
import '../core/notifications/widget_manager.dart';
import 'core_providers.dart';

enum TrendingPeriod { daily, weekly, monthly }

final trendingPeriodProvider = StateProvider<TrendingPeriod>((ref) => TrendingPeriod.weekly);
final trendingLanguageProvider = StateProvider<String?>((ref) => null);

/// "Trending" search provider. Fetches live GitHub repos.
/// Uses random page indexing (1..5) so pull-to-refresh fetches fresh new repos every time!
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

  // Generate random page 1..5 for variety on refresh
  final randomPage = Random().nextInt(5) + 1;

  final result = await api.searchRepositories(
    query: '',
    language: language,
    minStars: 5,
    sort: RepoSort.stars,
    period: searchPeriod,
    page: randomPage,
    perPage: 10,
  );

  if (result.items.isNotEmpty && period == TrendingPeriod.weekly) {
    WidgetManager.updateTrendingWidget(result.items.first);
  }

  return result;
});

/// Top developers search provider.
/// Uses random query offset so pull-to-refresh fetches fresh developers every time!
final topUsersProvider =
    FutureProvider.autoDispose<SearchUsersResult>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  final randomQueries = [
    'followers:>2000',
    'followers:>1500',
    'followers:>1000',
    'followers:>800',
    'followers:>500',
  ];
  final randomQuery = randomQueries[Random().nextInt(randomQueries.length)];
  final randomPage = Random().nextInt(3) + 1;

  final searchResult = await api.searchUsers(
    query: randomQuery,
    type: 'user',
    page: randomPage,
    perPage: 10,
  );
  
  if (searchResult.items.isEmpty) return searchResult;

  final detailedUsers = await Future.wait(
    searchResult.items.map((user) => api.getUserDetail(user.login)),
  );
  
  return SearchUsersResult(detailedUsers, searchResult.totalCount);
});

final topOrgsProvider =
    FutureProvider.autoDispose<SearchUsersResult>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.searchUsers(query: 'repos:>50', type: 'org');
});

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
