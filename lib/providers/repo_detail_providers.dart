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
