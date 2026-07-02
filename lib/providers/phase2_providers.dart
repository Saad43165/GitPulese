import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/manifest_parser.dart';
import '../data/models/repo_model.dart';
import '../data/remote/groq_api_service.dart';
import 'core_providers.dart';

// ---------- Compare Mode ----------

class CompareListNotifier extends StateNotifier<List<GhRepo>> {
  CompareListNotifier() : super([]);

  void add(GhRepo repo) {
    if (state.any((r) => r.id == repo.id) || state.length >= 3) return;
    state = [...state, repo];
  }

  void remove(int repoId) {
    state = state.where((r) => r.id != repoId).toList();
  }

  void clear() => state = [];

  bool contains(int repoId) => state.any((r) => r.id == repoId);
}

final compareListProvider =
    StateNotifierProvider<CompareListNotifier, List<GhRepo>>((ref) => CompareListNotifier());

// ---------- Similar / Alternative Repos ----------

final similarReposProvider =
    FutureProvider.autoDispose.family<List<GhRepo>, GhRepo>((ref, repo) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.findSimilarRepos(repo);
});

// ---------- Recent Commits ----------

final repoCommitsProvider = FutureProvider.autoDispose
    .family<List<GhCommit>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getRepoCommits(args.owner, args.repo, perPage: 10);
});

// ---------- Star History ----------

final starHistoryProvider = FutureProvider.autoDispose
    .family<List<MapEntry<DateTime, int>>, GhRepo>((ref, repo) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getStarHistory(repo.owner.login, repo.name, totalStars: repo.stargazersCount);
});

// ---------- Dependency / License Risk Checker ----------

class RiskCheckResult {
  final ManifestParseResult? manifest;
  final bool repoLicenseIsCopyleft;
  final String? repoLicenseName;
  RiskCheckResult({this.manifest, required this.repoLicenseIsCopyleft, this.repoLicenseName});
}

final dependencyRiskProvider =
    FutureProvider.autoDispose.family<RiskCheckResult, GhRepo>((ref, repo) async {
  final api = ref.watch(githubApiServiceProvider);
  final owner = repo.owner.login;
  final name = repo.name;

  ManifestParseResult? manifest;

  final pubspec = await api.getFileContent(owner, name, 'pubspec.yaml');
  if (pubspec != null) {
    manifest = ManifestParser.parsePubspecYaml(pubspec);
  } else {
    final packageJson = await api.getFileContent(owner, name, 'package.json');
    if (packageJson != null) {
      manifest = ManifestParser.parsePackageJson(packageJson);
    } else {
      final requirements = await api.getFileContent(owner, name, 'requirements.txt');
      if (requirements != null) {
        manifest = ManifestParser.parseRequirementsTxt(requirements);
      }
    }
  }

  final licenseKey = repo.license?.key.toLowerCase();
  final isCopyleft = licenseKey != null && copyleftLicenseIds.contains(licenseKey);

  return RiskCheckResult(
    manifest: manifest,
    repoLicenseIsCopyleft: isCopyleft,
    repoLicenseName: repo.license?.name,
  );
});

// ---------- Security Advisories ----------

final _ecosystemByLanguage = {
  'Dart': 'pub',
  'JavaScript': 'npm',
  'TypeScript': 'npm',
  'Python': 'pip',
  'Ruby': 'rubygems',
  'Java': 'maven',
  'C#': 'nuget',
  'Go': 'go',
  'Rust': 'rust',
  'PHP': 'composer',
};

final securityAdvisoriesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, GhRepo>((ref, repo) async {
  final ecosystem = _ecosystemByLanguage[repo.language];
  if (ecosystem == null) return [];
  final api = ref.watch(githubApiServiceProvider);
  return api.getSecurityAdvisories(ecosystem: ecosystem, packageName: repo.name);
});

// ---------- AI Repo Summarizer (via backend proxy, no key needed) ----------

/// Not auto-fetched — the user taps "Summarize" explicitly since this
/// costs a real LLM call on the shared backend. Family key is the repo id.
class RepoSummaryNotifier extends StateNotifier<AsyncValue<String>?> {
  RepoSummaryNotifier(this.ref) : super(null);
  final Ref ref;

  Future<void> summarize(GhRepo repo, String? readme) async {
    state = const AsyncValue.loading();
    try {
      final groq = GroqApiService();
      final summary = await groq.summarizeRepo(
        repoFullName: repo.fullName,
        description: repo.description,
        readme: readme,
        primaryLanguage: repo.language,
        topics: repo.topics,
      );
      if (!mounted) return;
      state = AsyncValue.data(summary);
    } catch (e) {
      if (!mounted) return;
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void reset() => state = null;
}

final repoSummaryProvider =
    StateNotifierProvider.autoDispose.family<RepoSummaryNotifier, AsyncValue<String>?, int>(
  (ref, repoId) => RepoSummaryNotifier(ref),
);
