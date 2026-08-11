import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/repo_model.dart';
import '../providers/core_providers.dart';
import '../core/network/dio_client.dart';

/// Tracks whether the last getRepoDetail call fell back to the SQLite cache.
/// The UI reads this to show a "Showing cached data" banner.
final repoDetailIsOfflineCacheProvider =
    StateProvider.autoDispose.family<bool, ({String owner, String repo})>(
  (ref, args) => false,
);

final repoDetailProvider = FutureProvider.autoDispose
    .family<GhRepo, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  try {
    final repo = await api.getRepoDetail(args.owner, args.repo);
    ref.read(repoDetailIsOfflineCacheProvider(args).notifier).state = false;
    return repo;
  } on GitHubApiException catch (e) {
    if (e.message.contains('No internet') || e.message.contains('timed out')) {
      // Mark as offline cache — the API service already tried SQLite and either
      // returned data (won't reach here) or will rethrow. Mark it anyway so
      // the banner appears if data was returned from catch in the service.
      ref.read(repoDetailIsOfflineCacheProvider(args).notifier).state = true;
    }
    rethrow;
  }
});

final repoReadmeProvider = FutureProvider.autoDispose
    .family<String?, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoReadme(args.owner, args.repo);
});

final repoLanguagesProvider = FutureProvider.autoDispose
    .family<Map<String, int>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoLanguages(args.owner, args.repo);
});

final repoContributorsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoContributors(args.owner, args.repo);
});

final repoReleasesProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoReleases(args.owner, args.repo);
});

final repoPullRequestsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  final result = await api.searchIssues(
    query: 'repo:${args.owner}/${args.repo}', 
    pullRequestsOnly: true,
  );
  return result.items;
});

final repoContentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo, String path})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoContents(args.owner, args.repo, args.path);
});
