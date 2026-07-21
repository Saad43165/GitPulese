import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String? issueSort; // 'comments', 'reactions', 'updated', 'created'
  final String? userType; // 'all', 'user', 'org'
  final String? userSort; // 'followers', 'repositories', 'joined'
  final String? userLocation;
  final String? codeExtension;

  const SearchFilters({
    this.language,
    this.minStars,
    this.license,
    this.sort = RepoSort.bestMatch,
    this.period = SearchPeriod.allTime,
    this.pullRequestsOnly = false,
    this.issueState = 'open',
    this.issueSort,
    this.userType = 'all',
    this.userSort,
    this.userLocation,
    this.codeExtension,
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
    String? issueSort,
    bool clearIssueSort = false,
    String? userType,
    String? userSort,
    bool clearUserSort = false,
    String? userLocation,
    bool clearUserLocation = false,
    String? codeExtension,
    bool clearCodeExtension = false,
  }) {
    return SearchFilters(
      language: clearLanguage ? null : (language ?? this.language),
      minStars: clearMinStars ? null : (minStars ?? this.minStars),
      license: clearLicense ? null : (license ?? this.license),
      sort: sort ?? this.sort,
      period: period ?? this.period,
      pullRequestsOnly: pullRequestsOnly ?? this.pullRequestsOnly,
      issueState: issueState ?? this.issueState,
      issueSort: clearIssueSort ? null : (issueSort ?? this.issueSort),
      userType: userType ?? this.userType,
      userSort: clearUserSort ? null : (userSort ?? this.userSort),
      userLocation: clearUserLocation ? null : (userLocation ?? this.userLocation),
      codeExtension: clearCodeExtension ? null : (codeExtension ?? this.codeExtension),
    );
  }

  int get activeCount {
    var c = 0;
    if (language != null) c++;
    if (minStars != null) c++;
    if (license != null) c++;
    if (sort != RepoSort.bestMatch) c++;
    if (period != SearchPeriod.allTime) c++;
    if (pullRequestsOnly) c++;
    if (issueState != 'open') c++;
    if (issueSort != null) c++;
    if (userType != 'all' && userType != null) c++;
    if (userSort != null) c++;
    if (userLocation != null && userLocation!.isNotEmpty) c++;
    if (codeExtension != null && codeExtension!.isNotEmpty) c++;
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

  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);
  await Future.delayed(const Duration(milliseconds: 500));
  if (isDisposed) return null;

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

  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);
  await Future.delayed(const Duration(milliseconds: 500));
  if (isDisposed) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchCode(
    query: query,
    language: filters.language,
    extension: filters.codeExtension,
  );
});

final userSearchProvider =
    FutureProvider.autoDispose<SearchUsersResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (query.trim().isEmpty) return null;

  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);
  await Future.delayed(const Duration(milliseconds: 500));
  if (isDisposed) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchUsers(
    query: query,
    type: filters.userType,
    sort: filters.userSort,
    language: filters.language,
    location: filters.userLocation,
  );
});

final issueSearchProvider =
    FutureProvider.autoDispose<SearchIssuesResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (query.trim().isEmpty) return null;

  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);
  await Future.delayed(const Duration(milliseconds: 500));
  if (isDisposed) return null;

  final api = ref.watch(githubApiServiceProvider);
  return api.searchIssues(
    query: query,
    pullRequestsOnly: filters.pullRequestsOnly,
    state: filters.issueState,
    sort: filters.issueSort,
  );
});

/// Pagination cursor for "load more" on repo search (used by the search screen).
final repoSearchPageProvider = StateProvider.autoDispose<int>((ref) => 1);
