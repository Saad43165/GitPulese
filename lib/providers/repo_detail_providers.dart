import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/repo_model.dart';
import '../providers/core_providers.dart';

final repoDetailProvider = FutureProvider.autoDispose
    .family<GhRepo, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoDetail(args.owner, args.repo);
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
