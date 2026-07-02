import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/repo_model.dart';
import '../data/models/user_and_search_models.dart';
import '../data/remote/github_api_service.dart';
import 'core_providers.dart';

enum SearchTab { repositories, code, users, issues }

class SearchFilters {
  final String? language;
  final int? minStars;
  final String? license;
  final RepoSort sort;
  final SearchPeriod period;
  final bool pullRequestsOnly;
  final String issueState;

  const SearchFilters({
    this.language,
    this.minStars,
    this.license,
    this.sort = RepoSort.bestMatch,
    this.period = SearchPeriod.allTime,
    this.pullRequestsOnly = false,
    this.issueState = 'open',
  });

  SearchFilters copyWith({
    String? language,
    bool clearLanguage = false,
    int? minStars,
    bool clearMinStars = false,
    String? license,
    bool clearLicense = false,
    RepoSort? sort,
    SearchPeriod? period,
    bool? pullRequestsOnly,
    String? issueState,
  }) {
    return SearchFilters(
      language: clearLanguage ? null : (language ?? this.language),
      minStars: clearMinStars ? null : (minStars ?? this.minStars),
      license: clearLicense ? null : (license ?? this.license),
      sort: sort ?? this.sort,
      period: period ?? this.period,
      pullRequestsOnly: pullRequestsOnly ?? this.pullRequestsOnly,
      issueState: issueState ?? this.issueState,
    );
  }

  int get activeCount {
    var c = 0;
    if (language != null) c++;
    if (minStars != null) c++;
    if (license != null) c++;
    if (sort != RepoSort.bestMatch) c++;
    if (period != SearchPeriod.allTime) c++;
    return c;
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchTabProvider = StateProvider<SearchTab>((ref) => SearchTab.repositories);
final searchFiltersProvider = StateProvider<SearchFilters>((ref) => const SearchFilters());

/// Real, paginated repo search. Re-fetches whenever query/filters change.
final repoSearchProvider =
    FutureProvider.autoDispose<SearchReposResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (query.trim().isEmpty) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchRepositories(
    query: query,
    language: filters.language,
    minStars: filters.minStars,
    license: filters.license,
    sort: filters.sort,
    period: filters.period,
  );
});

final codeSearchProvider =
    FutureProvider.autoDispose<SearchCodeResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (query.trim().isEmpty) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchCode(query: query, language: filters.language);
});

final userSearchProvider =
    FutureProvider.autoDispose<SearchUsersResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchUsers(query: query);
});

final issueSearchProvider =
    FutureProvider.autoDispose<SearchIssuesResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (query.trim().isEmpty) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchIssues(
    query: query,
    pullRequestsOnly: filters.pullRequestsOnly,
    state: filters.issueState,
  );
});

/// Pagination cursor for "load more" on repo search (used by the search screen).
final repoSearchPageProvider = StateProvider.autoDispose<int>((ref) => 1);
