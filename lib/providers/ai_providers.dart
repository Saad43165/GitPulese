import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/manifest_parser.dart';
import '../data/models/repo_model.dart';
import '../data/remote/github_api_service.dart';
import '../data/remote/groq_api_service.dart';
import 'core_providers.dart';
import 'settings_providers.dart';

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

// ---------- Repository Forking ----------

final repoForkProvider = StateNotifierProvider.family<ForkNotifier, AsyncValue<bool>, ({String owner, String repo})>((ref, args) {
  return ForkNotifier(ref.watch(githubApiServiceProvider), args);
});

class ForkNotifier extends StateNotifier<AsyncValue<bool>> {
  final GitHubApiService api;
  final ({String owner, String repo}) args;

  ForkNotifier(this.api, this.args) : super(const AsyncValue.loading()) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final isForked = await api.checkFork(args.owner, args.repo);
      if (mounted) state = AsyncValue.data(isForked);
    } catch (_) {
      if (mounted) state = const AsyncValue.data(false);
    }
  }

  Future<void> fork() async {
    final current = state.valueOrNull ?? false;
    if (current) return; // Already forked — nothing to do
    state = const AsyncValue.loading();
    try {
      await api.forkRepo(args.owner, args.repo);
      
      // Poll GitHub API until the fork is actually created and visible
      bool isForked = false;
      int attempts = 0;
      while (attempts < 10 && !isForked) {
        await Future.delayed(const Duration(seconds: 1));
        isForked = await api.checkFork(args.owner, args.repo);
        attempts++;
      }
      
      if (mounted) state = AsyncValue.data(isForked);
    } catch (e) {
      if (mounted) state = const AsyncValue.data(false); // Revert on fail
      rethrow;
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
    Object? lastError;
    StackTrace? lastStack;

    // Strategy 1-3: Try diff-based summaries (progressive limits: 3000, 1500, 800)
    try {
      final diff = await github.getPullRequestDiff(owner, repo, pullNumber);
      if (diff != null && diff.isNotEmpty) {
        final limits = [3000, 1500, 800];

        for (final limit in limits) {
          final truncatedDiff = diff.length > limit
              ? '${diff.substring(0, limit)}\n\n...[Diff truncated — showing first $limit chars]'
              : diff;

          try {
            final explanation = await groq.explainCode(
              filename: 'Pull Request #$pullNumber: $title',
              code: truncatedDiff,
            );
            if (!mounted) return;
            state = AsyncValue.data(explanation);
            return; // success — stop retrying
          } catch (e, st) {
            final errStr = e.toString();
            // Continue/retry on 500/rate-limit/429 errors
            if (!errStr.contains('500') && !errStr.contains('rate') && !errStr.contains('429')) {
              // Propagate if it's another error kind, but we will still fall back to metadata if retry fails
            }
            lastError = e;
            lastStack = st;
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      } else {
        lastError = 'PR diff is empty or restricted';
        lastStack = StackTrace.empty;
      }
    } catch (e, st) {
      lastError = e;
      lastStack = st;
    }

    // Strategy 4 Fallback: Summarize based on PR title, description, and list of files
    if (!mounted) return;
    try {
      final prDetails = await github.getPullRequestDetails(owner, repo, pullNumber);
      final prFiles = await github.getPullRequestFiles(owner, repo, pullNumber);
      final body = prDetails?['body'] as String? ?? 'No description provided.';
      
      final fileSummary = prFiles.map((f) {
        final filename = f['filename'] as String? ?? 'unknown';
        final status = f['status'] as String? ?? 'modified';
        final additions = f['additions'] as int? ?? 0;
        final deletions = f['deletions'] as int? ?? 0;
        return '- $filename ($status, +$additions -$deletions)';
      }).join('\n');

      final summaryPrompt = 'This Pull Request diff was unavailable or too large. Here is the metadata, description, and files changed:\n\n'
          'Title: $title\n'
          'Description:\n$body\n\n'
          'Files Changed:\n$fileSummary';

      final explanation = await groq.explainCode(
        filename: 'Pull Request #$pullNumber: $title (Metadata Summary)',
        code: summaryPrompt,
      );
      if (mounted) {
        state = AsyncValue.data(explanation);
        return;
      }
    } catch (e, st) {
      lastError = e;
      lastStack = st;
    }

    // All attempts failed
    if (!mounted) return;
    state = AsyncValue.error(lastError ?? 'Unknown error', lastStack ?? StackTrace.current);
  }
}

// ---------- User Following ----------

// Per-username accumulated delta for THIS session (resets when provider is disposed).
// Stored as a map so multiple profiles can be tracked independently.
final followDeltaMapProvider = StateProvider<Map<String, int>>((ref) => {});

/// Public helper: read the net follow-delta for a specific target username.
/// Returns the change in the viewer's *own* following count caused by following/
/// unfollowing [targetUsername] during this session.
int followDeltaForUser(Map<String, int> map, String targetUsername) =>
    map[targetUsername] ?? 0;

final userFollowProvider =
    StateNotifierProvider.family<FollowNotifier, AsyncValue<bool>, String>(
        (ref, username) {
  return FollowNotifier(ref, ref.watch(githubApiServiceProvider), username);
});

class FollowNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  final GitHubApiService _api;
  final String _username;

  /// The confirmed server-side state after the last successful API call.
  bool? _serverState;

  FollowNotifier(this._ref, this._api, this._username)
      : super(const AsyncValue.loading()) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final isFollowing = await _api.checkFollow(_username);
      _serverState = isFollowing;
      if (mounted) state = AsyncValue.data(isFollowing);
    } catch (_) {
      // Can't check (e.g. no PAT) — assume not following
      if (mounted) state = const AsyncValue.data(false);
    }
  }

  /// +1 if auth user just followed this person, -1 if just unfollowed, 0 otherwise.
  /// Used to show live follower count on the viewed profile.
  int get followersDelta {
    if (_serverState == null) return 0;
    final optimistic = state.valueOrNull;
    if (optimistic == null) return 0;
    if (!_serverState! && optimistic) return 1;  // was not following, now following
    if (_serverState! && !optimistic) return -1; // was following, now unfollowed
    return 0;
  }

  /// Net change to the authenticated user's OWN following count.
  int get sessionDelta =>
      _ref.read(followDeltaMapProvider)[_username] ?? 0;

  Future<void> toggleFollow() async {
    final current = state.valueOrNull ?? false;
    final next = !current;

    // 1. Optimistic UI update immediately
    state = AsyncValue.data(next);

    // 2. Track per-username delta
    final map = Map<String, int>.from(_ref.read(followDeltaMapProvider));
    map[_username] = (map[_username] ?? 0) + (next ? 1 : -1);
    _ref.read(followDeltaMapProvider.notifier).state = map;

    try {
      await _api.followUser(_username, follow: next);
      // Update confirmed server state
      _serverState = next;

      // 3. Invalidate the following list so it refreshes on next open
      _ref.invalidate(userDetailProvider(_username));
    } catch (e) {
      // Revert optimistic update on failure
      state = AsyncValue.data(current);

      final revertMap = Map<String, int>.from(_ref.read(followDeltaMapProvider));
      revertMap[_username] = (revertMap[_username] ?? 0) - (next ? 1 : -1);
      _ref.read(followDeltaMapProvider.notifier).state = revertMap;

      rethrow; // Let UI show the error
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

class PrReviewResult {
  final String owner;
  final String repo;
  final int pullNumber;
  final String title;
  final String author;
  final String reviewMarkdown;
  final String branchName;
  final String diff;

  PrReviewResult({
    required this.owner,
    required this.repo,
    required this.pullNumber,
    required this.title,
    required this.author,
    required this.reviewMarkdown,
    required this.branchName,
    required this.diff,
  });
}

class PrReviewNotifier extends StateNotifier<AsyncValue<PrReviewResult?>> {
  final GroqApiService groq;
  final GitHubApiService github;

  PrReviewNotifier(this.groq, this.github) : super(const AsyncValue.data(null));

  Future<void> reviewPullRequest(String url) async {
    state = const AsyncValue.loading();
    try {
      final prRegex = RegExp(
        r'github\.com/([^/]+)/([^/]+)/pull/(\d+)',
        caseSensitive: false,
      );
      final match = prRegex.firstMatch(url);
      if (match == null) {
        state = AsyncValue.error('Invalid GitHub Pull Request URL. Please enter a valid PR link (e.g. github.com/owner/repo/pull/123).', StackTrace.current);
        return;
      }

      final owner = match.group(1)!;
      final repo = match.group(2)!;
      final pullNumber = int.parse(match.group(3)!);

      String title = 'Pull Request #$pullNumber';
      String author = 'unknown';
      String description = 'No description provided.';
      String branchName = 'main';

      try {
        final details = await github.getPullRequestDetails(owner, repo, pullNumber);
        if (details != null) {
          title = details['title'] as String? ?? title;
          author = (details['user'] as Map<String, dynamic>?)?['login'] as String? ?? author;
          description = details['body'] as String? ?? description;
          if (details['head'] != null && details['head']['ref'] != null) {
            branchName = details['head']['ref'] as String;
          }
        }
      } catch (_) {
        // Fallback: Proceed even if details API fails
      }

      final diff = await github.getPullRequestDiff(owner, repo, pullNumber);
      if (diff == null || diff.isEmpty) {
        state = AsyncValue.error('Pull request has no code diff or the diff is empty. Make sure the repository is public and the PR number is correct.', StackTrace.current);
        return;
      }

      // Truncate to keep within context window limitations
      final truncatedDiff = diff.length > 4000 ? '${diff.substring(0, 4000)}\n\n...[Diff Truncated for length]' : diff;

      final prompt = '''
Please perform a thorough, professional, and structured Code Review of the following pull request.

PR Title: $title
PR Description: $description
PR Author: $author

You MUST structure your review into the following sections exactly:

### 🐞 Bugs Found
Identify any logic bugs, syntax errors, edge-case crashes, type mismatches, or incorrect behaviors in the diff. Be specific.

### 🔒 Security Issues
Identify any security flaws, hardcoded credentials/secrets, potential injection vulnerabilities, unsafe dependencies, or privilege issues.

### 💡 Suggestions & Refactoring
Provide actionable suggestions for performance optimization, clean code best practices, documentation, readability, and testing.

Here is the pull request diff:
```diff
$truncatedDiff
```
''';

      final reviewMarkdown = await groq.explainCode(
        filename: 'Pull Request Review: #$pullNumber - $title',
        code: prompt,
      );

      if (!mounted) return;
      state = AsyncValue.data(
        PrReviewResult(
          owner: owner,
          repo: repo,
          pullNumber: pullNumber,
          title: title,
          author: author,
          reviewMarkdown: reviewMarkdown,
          branchName: branchName,
          diff: diff,
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final prReviewProvider = StateNotifierProvider.autoDispose<PrReviewNotifier, AsyncValue<PrReviewResult?>>((ref) {
  return PrReviewNotifier(ref.watch(groqApiServiceProvider), ref.watch(githubApiServiceProvider));
});

final repoPullRequestsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getPullRequests(args.owner, args.repo);
});

final prFilesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String owner, String repo, int pullNumber})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getPullRequestFiles(args.owner, args.repo, args.pullNumber);
});

class PrPatchNotifier extends StateNotifier<AsyncValue<String?>> {
  PrPatchNotifier(this.groq, this.github) : super(const AsyncValue.data(null));

  final GroqApiService groq;
  final GitHubApiService github;

  Future<void> generatePatch({
    required String owner,
    required String repo,
    required String path,
    required String branch,
    required String prDiff,
    required String reviewComments,
  }) async {
    state = const AsyncValue.loading();
    try {
      final fileContent = await github.getFileRawContent(owner, repo, path);

      final prompt = '''
You are an expert AI code refactoring engine. Your task is to resolve code quality, bugs, or security recommendations in a file based on a code review and a PR diff.

Target File Path: $path
Original File Content:
```
$fileContent
```

Pull Request Diff:
```diff
$prDiff
```

Code Review / Quality Audit:
```markdown
$reviewComments
```

Please output ONLY the complete, correct, and modified content of the target file. 
- Do NOT wrap your output in markdown code blocks like ```dart or ```.
- Do NOT write any introduction or summary explanations. 
- Output the raw code content exactly.
''';

      final patchedCode = await groq.explainCode(
        filename: 'Auto Patch: $path',
        code: prompt,
      );

      var cleanCode = patchedCode.trim();
      if (cleanCode.startsWith('```')) {
        final firstLineBreak = cleanCode.indexOf('\n');
        if (firstLineBreak != -1) {
          cleanCode = cleanCode.substring(firstLineBreak + 1);
        }
        if (cleanCode.endsWith('```')) {
          cleanCode = cleanCode.substring(0, cleanCode.length - 3).trim();
        }
      }

      state = AsyncValue.data(cleanCode);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final prPatchProvider = StateNotifierProvider.autoDispose<PrPatchNotifier, AsyncValue<String?>>((ref) {
  return PrPatchNotifier(ref.watch(groqApiServiceProvider), ref.watch(githubApiServiceProvider));
});
