import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/manifest_parser.dart';
import '../data/models/repo_model.dart';
import '../data/remote/github_api_service.dart';
import '../data/remote/groq_api_service.dart';
import 'core_providers.dart';

final groqApiServiceProvider = Provider<GroqApiService>((ref) => GroqApiService());

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

// ---------- Repository Starring ----------

final repoStarProvider = StateNotifierProvider.family<StarNotifier, AsyncValue<bool>, ({String owner, String repo})>((ref, args) {
  return StarNotifier(ref.watch(githubApiServiceProvider), args);
});

class StarNotifier extends StateNotifier<AsyncValue<bool>> {
  final GitHubApiService api;
  final ({String owner, String repo}) args;
  
  StarNotifier(this.api, this.args) : super(const AsyncValue.loading()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    try {
      final isStarred = await api.checkStar(args.owner, args.repo);
      if (mounted) state = AsyncValue.data(isStarred);
    } catch (e) {
      if (mounted) state = const AsyncValue.data(false);
    }
  }

  Future<void> toggleStar() async {
    final current = state.valueOrNull ?? false;
    state = AsyncValue.data(!current); // Optimistic update
    try {
      await api.starRepo(args.owner, args.repo, star: !current);
    } catch (e) {
      if (mounted) state = AsyncValue.data(current); // Revert on fail
    }
  }
}

// ---------- AI Developer Analyzer ----------

class DeveloperAnalyzerNotifier extends StateNotifier<AsyncValue<String?>> {
  DeveloperAnalyzerNotifier(this.groq) : super(const AsyncValue.data(null));

  final GroqApiService groq;

  Future<void> analyzeDeveloper({
    required String username,
    required String? bio,
    required List<GhRepo> topRepos,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repos = topRepos
          .map((r) => {
                'name': r.name,
                'description': r.description,
                'language': r.language,
                'stars': r.stargazersCount,
                'topics': r.topics,
              })
          .toList();
      final analysis = await groq.analyzeDeveloper(
        username: username,
        bio: bio,
        repos: repos,
      );
      if (!mounted) return;
      state = AsyncValue.data(analysis);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final developerAnalyzerProvider =
    StateNotifierProvider.autoDispose.family<DeveloperAnalyzerNotifier, AsyncValue<String?>, String>((ref, username) {
  return DeveloperAnalyzerNotifier(ref.watch(groqApiServiceProvider));
});

// ---------- AI Code Explainer ----------

final codeExplainerProvider = StateNotifierProvider.autoDispose<CodeExplainerNotifier, AsyncValue<String?>>((ref) {
  return CodeExplainerNotifier(ref.watch(groqApiServiceProvider), ref.watch(githubApiServiceProvider));
});


class CodeExplainerNotifier extends StateNotifier<AsyncValue<String?>> {
  final GroqApiService groq;
  final GitHubApiService github;
  CodeExplainerNotifier(this.groq, this.github) : super(const AsyncValue.data(null));

  Future<void> explainCode({
    required String owner,
    required String repo,
    required String path,
    required String filename,
  }) async {
    state = const AsyncValue.loading();
    try {
      final code = await github.getFileRawContent(owner, repo, path);
      final explanation = await groq.explainCode(filename: filename, code: code);
      if (!mounted) return;
      state = AsyncValue.data(explanation);
    } catch (e) {
      if (!mounted) return;
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// ---------- AI Pull Request Summarizer ----------

final prSummaryProvider = StateNotifierProvider.autoDispose<PrSummaryNotifier, AsyncValue<String?>>((ref) {
  return PrSummaryNotifier(ref.watch(groqApiServiceProvider), ref.watch(githubApiServiceProvider));
});

class PrSummaryNotifier extends StateNotifier<AsyncValue<String?>> {
  final GroqApiService groq;
  final GitHubApiService github;
  PrSummaryNotifier(this.groq, this.github) : super(const AsyncValue.data(null));

  Future<void> summarizePR({
    required String owner,
    required String repo,
    required int pullNumber,
    required String title,
  }) async {
    state = const AsyncValue.loading();
    try {
      final diff = await github.getPullRequestDiff(owner, repo, pullNumber);
      if (diff == null || diff.isEmpty) {
        state = const AsyncValue.error('Pull request diff is empty or not found.', StackTrace.empty);
        return;
      }
      
      // Limit diff size to avoid token limit errors
      final truncatedDiff = diff.length > 3000 ? '${diff.substring(0, 3000)}\n...[Diff Truncated]' : diff;
      
      // We can cleverly use the explain-code endpoint for PR diffs too
      final explanation = await groq.explainCode(
        filename: 'Pull Request: $title',
        code: truncatedDiff,
      );
      if (!mounted) return;
      state = AsyncValue.data(explanation);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

// ---------- User Following ----------

final followingDeltaProvider = StateProvider<int>((ref) => 0);

final userFollowProvider = StateNotifierProvider.family<FollowNotifier, AsyncValue<bool>, String>((ref, username) {
  return FollowNotifier(ref, ref.watch(githubApiServiceProvider), username);
});

class FollowNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final GitHubApiService api;
  final String username;
  bool? _initialFollowState;
  
  FollowNotifier(this.ref, this.api, this.username) : super(const AsyncValue.loading()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    try {
      final isFollowing = await api.checkFollow(username);
      _initialFollowState = isFollowing;
      if (mounted) state = AsyncValue.data(isFollowing);
    } catch (e) {
      if (mounted) state = const AsyncValue.data(false);
    }
  }

  int get followersDelta {
    if (_initialFollowState == null) return 0;
    final current = state.valueOrNull ?? false;
    if (_initialFollowState == false && current == true) return 1;
    if (_initialFollowState == true && current == false) return -1;
    return 0;
  }

  Future<void> toggleFollow() async {
    final current = state.valueOrNull ?? false;
    final next = !current;
    state = AsyncValue.data(next); // Optimistic update
    ref.read(followingDeltaProvider.notifier).state += (next ? 1 : -1);
    
    try {
      await api.followUser(username, follow: next);
    } catch (e) {
      ref.read(followingDeltaProvider.notifier).state -= (next ? 1 : -1);
      if (mounted) state = AsyncValue.data(current); // Revert on fail
    }
  }
}

class CompareAiNotifier extends StateNotifier<AsyncValue<String?>> {
  final GroqApiService groq;
  CompareAiNotifier(this.groq) : super(const AsyncValue.data(null));

  Future<void> runComparison(List<GhRepo> repos) async {
    if (repos.length < 2) return;
    state = const AsyncValue.loading();
    try {
      final summary = await groq.summarizeRepo(
        repoFullName: 'Repository Comparison Arena',
        description: 'Comparing ${repos.map((r) => r.fullName).join(' vs ')}',
        readme: '''
You are an expert software architect comparing repositories in the 'AI Repo Arena'.
Please compare the following repositories in detail and provide a final verdict on which one to choose for different scenarios:

${repos.map((r) => '''
- Repository: ${r.fullName}
  Stars: ${r.stargazersCount}
  Forks: ${r.forksCount}
  Open Issues: ${r.openIssuesCount}
  Language: ${r.language ?? 'Mixed'}
  Description: ${r.description ?? 'No description'}
  Health Score: ${r.healthScore}
''').join('\n')}

Format your response cleanly:
1. Short overview of the comparison
2. Side-by-side strengths and weaknesses of each (brief bullet points)
3. Direct Verdict: "Choose A if..., Choose B if..."
''',
        primaryLanguage: 'Comparison',
        topics: ['compare', 'arena'],
      );
      state = AsyncValue.data(summary);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  void reset() => state = const AsyncValue.data(null);
}

final compareAiProvider = StateNotifierProvider.autoDispose<CompareAiNotifier, AsyncValue<String?>>((ref) {
  return CompareAiNotifier(ref.watch(groqApiServiceProvider));
});
