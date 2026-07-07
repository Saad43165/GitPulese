import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/repo_model.dart';
import '../models/user_and_search_models.dart';

enum RepoSort { bestMatch, stars, forks, updated }
enum SearchPeriod { allTime, today, thisWeek, thisMonth, thisYear }

class SearchReposResult {
  final List<GhRepo> items;
  final int totalCount;
  SearchReposResult(this.items, this.totalCount);
}

class SearchCodeResult {
  final List<GhCodeResult> items;
  final int totalCount;
  SearchCodeResult(this.items, this.totalCount);
}

class SearchUsersResult {
  final List<GhUser> items;
  final int totalCount;
  SearchUsersResult(this.items, this.totalCount);
}

class SearchIssuesResult {
  final List<GhIssue> items;
  final int totalCount;
  SearchIssuesResult(this.items, this.totalCount);
}

/// Real GitHub REST API v3 client. Every method below performs an actual
/// HTTP request — there is no mocked or hardcoded response anywhere here.
class GitHubApiService {
  GitHubApiService(this._dio);
  final Dio _dio;

  static String _sortParam(RepoSort sort) {
    switch (sort) {
      case RepoSort.stars:
        return 'stars';
      case RepoSort.forks:
        return 'forks';
      case RepoSort.updated:
        return 'updated';
      case RepoSort.bestMatch:
        return '';
    }
  }

  static String? _createdQualifier(SearchPeriod period) {
    final now = DateTime.now();
    DateTime since;
    switch (period) {
      case SearchPeriod.today:
        since = now.subtract(const Duration(days: 1));
        break;
      case SearchPeriod.thisWeek:
        since = now.subtract(const Duration(days: 7));
        break;
      case SearchPeriod.thisMonth:
        since = now.subtract(const Duration(days: 30));
        break;
      case SearchPeriod.thisYear:
        since = now.subtract(const Duration(days: 365));
        break;
      case SearchPeriod.allTime:
        return null;
    }
    final iso = since.toIso8601String().split('T').first;
    return 'created:>=$iso';
  }

  /// Returns the GitHub user who owns the current PAT (GET /user).
  Future<GhUser> getAuthenticatedUser() async {
    try {
      final response = await _dio.get('/user');
      return GhUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<SearchReposResult> searchRepositories({
    required String query,
    String? language,
    int? minStars,
    String? license,
    RepoSort sort = RepoSort.bestMatch,
    SearchPeriod period = SearchPeriod.allTime,
    int page = 1,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final qParts = <String>[query.trim().isEmpty ? '' : query.trim()];
    if (language != null && language.isNotEmpty) qParts.add('language:$language');
    if (minStars != null && minStars > 0) qParts.add('stars:>=$minStars');
    if (license != null && license.isNotEmpty) qParts.add('license:$license');
    final created = _createdQualifier(period);
    if (created != null) qParts.add(created);

    final q = qParts.where((e) => e.isNotEmpty).join(' ');

    try {
      final response = await _dio.get(
        ApiConstants.searchRepos,
        queryParameters: {
          'q': q.isEmpty ? 'stars:>1' : q,
          if (sort != RepoSort.bestMatch) 'sort': _sortParam(sort),
          'order': 'desc',
          'page': page,
          'per_page': perPage,
        },
      );
      final items = (response.data['items'] as List<dynamic>)
          .map((e) => GhRepo.fromJson(e as Map<String, dynamic>))
          .toList();
      return SearchReposResult(items, response.data['total_count'] as int? ?? 0);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<SearchCodeResult> searchCode({
    required String query,
    String? language,
    String? filename,
    String? extension,
    int page = 1,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final qParts = <String>[query.trim()];
    if (language != null && language.isNotEmpty) qParts.add('language:$language');
    if (filename != null && filename.isNotEmpty) qParts.add('filename:$filename');
    if (extension != null && extension.isNotEmpty) qParts.add('extension:$extension');
    final q = qParts.where((e) => e.isNotEmpty).join(' ');

    try {
      final response = await _dio.get(
        ApiConstants.searchCode,
        queryParameters: {'q': q, 'page': page, 'per_page': perPage},
      );
      final items = (response.data['items'] as List<dynamic>)
          .map((e) => GhCodeResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return SearchCodeResult(items, response.data['total_count'] as int? ?? 0);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<SearchUsersResult> searchUsers({
    required String query,
    String type = 'user', // 'user' or 'org'
    int page = 1,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final q = '${query.trim()} type:$type';
    try {
      final response = await _dio.get(
        ApiConstants.searchUsers,
        queryParameters: {
          'q': q,
          'sort': 'followers',
          'order': 'desc',
          'page': page,
          'per_page': perPage,
        },
      );
      final items = (response.data['items'] as List<dynamic>)
          .map((e) => GhUser.fromJson(e as Map<String, dynamic>))
          .toList();
      return SearchUsersResult(items, response.data['total_count'] as int? ?? 0);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<SearchIssuesResult> searchIssues({
    required String query,
    bool pullRequestsOnly = false,
    String state = 'open',
    int page = 1,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final qParts = <String>[
      query.trim(),
      if (pullRequestsOnly) 'is:pr' else 'is:issue',
      'state:$state',
    ];
    final q = qParts.where((e) => e.isNotEmpty).join(' ');

    try {
      final response = await _dio.get(
        ApiConstants.searchIssues,
        queryParameters: {'q': q, 'page': page, 'per_page': perPage},
      );
      final items = (response.data['items'] as List<dynamic>)
          .map((e) => GhIssue.fromJson(e as Map<String, dynamic>))
          .toList();
      return SearchIssuesResult(items, response.data['total_count'] as int? ?? 0);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<GhRepo> getRepoDetail(String owner, String repo) async {
    try {
      final response = await _dio.get(ApiConstants.repoDetail(owner, repo));
      return GhRepo.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }
  /// Returns decoded README markdown as plain text (decoded from base64).
  Future<String?> getRepoReadme(String owner, String repo) async {
    try {
      final response = await _dio.get(
        ApiConstants.repoReadme(owner, repo),
        options: Options(headers: {'Accept': 'application/vnd.github.v3.raw'}),
      );
      if (response.data is String) return response.data as String;
      // Fallback: base64 content field
      final content = response.data['content'] as String?;
      if (content == null) return null;
      try {
        return utf8.decode(base64.decode(content.replaceAll(RegExp(r'\s+'), '')));
      } catch (_) {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<Map<String, int>> getRepoLanguages(String owner, String repo) async {
    try {
      final response = await _dio.get(ApiConstants.repoLanguages(owner, repo));
      return (response.data as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<String?> getPullRequestDiff(String owner, String repo, int pullNumber) async {
    // 1. Try fetching via API with ResponseType.plain
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/pulls/$pullNumber',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3.diff'},
          responseType: ResponseType.plain,
        ),
      );
      if (response.data != null && response.data.toString().isNotEmpty) {
        return response.data.toString();
      }
    } catch (_) {
      // Ignore and fallback
    }

    // 2. Fallback: Fetch directly from public GitHub .diff URL using clean Dio instance
    try {
      final client = Dio();
      final fallbackUrl = 'https://github.com/$owner/$repo/pull/$pullNumber.diff';
      final response = await client.get(
        fallbackUrl,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data.toString();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw GitHubApiException.fromDioError(e);
    } catch (e) {
      throw GitHubApiException('Failed to download pull request diff: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPullRequestDetails(String owner, String repo, int pullNumber) async {
    try {
      final response = await _dio.get('/repos/$owner/$repo/pulls/$pullNumber');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPullRequestFiles(String owner, String repo, int pullNumber) async {
    try {
      final response = await _dio.get('/repos/$owner/$repo/pulls/$pullNumber/files');
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPullRequests(String owner, String repo, {String state = 'open', int perPage = 30}) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/pulls',
        queryParameters: {
          'state': state,
          'per_page': perPage,
        },
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<GhOwner>> getRepoContributors(String owner, String repo, {int perPage = 15}) async {
    try {
      final response = await _dio.get(
        ApiConstants.repoContributors(owner, repo),
        queryParameters: {'per_page': perPage},
      );
      return (response.data as List<dynamic>)
          .map((e) => GhOwner.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<GhUser>> getUserFollowers(String username, {int perPage = 30}) async {
    try {
      final response = await _dio.get(
        '/users/$username/followers',
        queryParameters: {'per_page': perPage},
      );
      return (response.data as List<dynamic>)
          .map((e) => GhUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<GhUser>> getUserFollowing(String username, {int perPage = 30}) async {
    try {
      final response = await _dio.get(
        '/users/$username/following',
        queryParameters: {'per_page': perPage},
      );
      return (response.data as List<dynamic>)
          .map((e) => GhUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<dynamic>> getRepoReleases(String owner, String repo, {int perPage = 10}) async {
    try {
      final response = await _dio.get(
        ApiConstants.repoReleases(owner, repo),
        queryParameters: {'per_page': perPage},
      );
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<GhUser> getUserDetail(String username) async {
    try {
      final response = await _dio.get(ApiConstants.userDetail(username));
      return GhUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<GhCommit>> getRepoCommits(String owner, String repo, {int perPage = 5}) async {
    try {
      final response = await _dio.get(
        ApiConstants.repoCommits(owner, repo),
        queryParameters: {'per_page': perPage},
      );
      return (response.data as List<dynamic>)
          .map((e) => GhCommit.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 || e.response?.statusCode == 404) return [];
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<List<GhRepo>> getUserRepos(String username, {int perPage = 30}) async {
    try {
      final response = await _dio.get(
        ApiConstants.userRepos(username),
        queryParameters: {'sort': 'updated', 'per_page': perPage},
      );
      return (response.data as List<dynamic>)
          .map((e) => GhRepo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Real star-growth data points, built from GitHub's stargazer-with-timestamp
  /// endpoint (requires the star+json media type). Samples up to [maxPages]
  /// pages (100/page) spaced evenly across the stargazer list so a repo with
  /// 50k+ stars doesn't require thousands of requests — each sampled point is
  /// still a real, actual stargazer timestamp from GitHub, not interpolated.
  Future<List<MapEntry<DateTime, int>>> getStarHistory(
    String owner,
    String repo, {
    required int totalStars,
    int samplePoints = 12,
  }) async {
    if (totalStars <= 0) return [];
    const perPage = 100;
    final totalPages = (totalStars / perPage).ceil().clamp(1, 4000);
    final pagesToSample = <int>{1, totalPages};
    if (totalPages > 2) {
      final step = (totalPages / samplePoints).ceil().clamp(1, totalPages);
      for (int p = 1; p <= totalPages; p += step) {
        pagesToSample.add(p);
      }
    }
    final sortedPages = pagesToSample.toList()..sort();

    final points = <MapEntry<DateTime, int>>[];
    for (final page in sortedPages) {
      try {
        final response = await _dio.get(
          '/repos/$owner/$repo/stargazers',
          queryParameters: {'page': page, 'per_page': perPage},
          options: Options(headers: {'Accept': 'application/vnd.github.star+json'}),
        );
        final list = response.data as List<dynamic>;
        if (list.isEmpty) continue;
        final first = list.first as Map<String, dynamic>;
        final starredAt = first['starred_at'] as String?;
        if (starredAt != null) {
          final date = DateTime.tryParse(starredAt);
          if (date != null) {
            points.add(MapEntry(date, (page - 1) * perPage + 1));
          }
        }
      } on DioException {
        // Skip a failed page sample rather than aborting the whole chart.
        continue;
      }
    }
    points.sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

  /// Fetches and base64-decodes a specific file's raw content from a repo,
  /// e.g. pubspec.yaml, package.json, requirements.txt. Returns null if the
  /// file doesn't exist (real 404, not a mock).
  Future<String?> getFileContent(String owner, String repo, String path) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/contents/$path',
        options: Options(headers: {'Accept': 'application/vnd.github.raw+json'}),
      );
      if (response.data is String) return response.data as String;
      final content = response.data['content'] as String?;
      if (content == null) return null;
      return utf8.decode(base64.decode(content.replaceAll('\n', '')));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Fetches the contents of a directory in a repository.
  /// If path is empty, it fetches the root directory.
  Future<List<Map<String, dynamic>>> getRepoContents(String owner, String repo, [String path = '']) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/contents/$path',
      );
      if (response.data is List) {
        return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Real GitHub global Security Advisories API, filtered by ecosystem +
  /// package name. Public endpoint, no special auth scope required.
  Future<List<Map<String, dynamic>>> getSecurityAdvisories({
    required String ecosystem, // npm, pip, rubygems, maven, nuget, pub, composer, go, rust
    required String packageName,
  }) async {
    try {
      final response = await _dio.get(
        '/advisories',
        queryParameters: {
          'ecosystem': ecosystem,
          'affects': packageName,
          'per_page': 20,
        },
      );
      return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// "Alternative repos" — real search using the repo's own topics/language,
  /// excluding the repo itself, sorted by stars. Not an official GitHub
  /// feature, but every result returned is a genuine, live search hit.
  Future<List<GhRepo>> findSimilarRepos(GhRepo source, {int perPage = 10}) async {
    final topicQuery = source.topics.take(3).map((t) => 'topic:$t').join(' ');
    final q = StringBuffer();
    if (topicQuery.isNotEmpty) {
      q.write(topicQuery);
    } else if (source.language != null) {
      q.write('language:${source.language}');
    } else {
      return [];
    }

    try {
      final response = await _dio.get(
        ApiConstants.searchRepos,
        queryParameters: {
          'q': q.toString(),
          'sort': 'stars',
          'order': 'desc',
          'per_page': perPage + 1,
        },
      );
      final items = (response.data['items'] as List<dynamic>)
          .map((e) => GhRepo.fromJson(e as Map<String, dynamic>))
          .where((r) => r.id != source.id)
          .take(perPage)
          .toList();
      return items;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<bool> checkStar(String owner, String repo) async {
    try {
      final response = await _dio.get(
        '/user/starred/$owner/$repo',
      );
      return response.statusCode == 204;
    } catch (e) {
      return false; // 404 means not starred
    }
  }

  Future<void> starRepo(String owner, String repo, {required bool star}) async {
    try {
      if (star) {
        await _dio.put(
          '/user/starred/$owner/$repo',
          data: {},
        );
      } else {
        await _dio.delete('/user/starred/$owner/$repo');
      }
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<String> getFileRawContent(String owner, String repo, String path) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/contents/$path',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3.raw'},
          responseType: ResponseType.plain,
        ),
      );
      
      final data = response.data;
      if (data == null) return '';

      // Handle raw string responses
      if (data is String) {
        // Check if response is actually a JSON string from proxy/mock server
        try {
          final decoded = json.decode(data);
          if (decoded is Map && decoded.containsKey('content')) {
            final base64Content = decoded['content'] as String;
            final cleanedBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
            return utf8.decode(base64.decode(cleanedBase64));
          }
        } catch (_) {
          // Not valid JSON or decoding failed, treat as raw text
        }
        return data;
      }

      // Handle parsed JSON Map responses
      if (data is Map) {
        if (data.containsKey('content')) {
          final base64Content = data['content'] as String;
          final cleanedBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
          return utf8.decode(base64.decode(cleanedBase64));
        }
      }

      return data.toString();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<Uint8List> getFileRawBytes(String owner, String repo, String path) async {
    try {
      final response = await _dio.get<List<int>>(
        '/repos/$owner/$repo/contents/$path',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3.raw'},
          responseType: ResponseType.bytes,
        ),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<bool> checkFollow(String username) async {
    try {
      final response = await _dio.get('/user/following/$username');
      return response.statusCode == 204;
    } catch (e) {
      return false; // 404 means not following
    }
  }

  Future<void> followUser(String username, {required bool follow}) async {
    try {
      if (follow) {
        await _dio.put(
          '/user/following/$username',
          data: {},
        );
      } else {
        await _dio.delete('/user/following/$username');
      }
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  Future<void> forkRepo(String owner, String repo) async {
    try {
      await _dio.post(
        '/repos/$owner/$repo/forks',
      );
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// List workflows for a repository (GET /repos/{owner}/{repo}/actions/workflows)
  Future<Map<String, dynamic>> getWorkflows(String owner, String repo) async {
    try {
      final response = await _dio.get('/repos/$owner/$repo/actions/workflows');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// List workflow runs for a repository (GET /repos/{owner}/{repo}/actions/runs)
  Future<Map<String, dynamic>> getWorkflowRuns(String owner, String repo, {int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/actions/runs',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Trigger a workflow dispatch event (POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches)
  Future<void> triggerWorkflowDispatch(
    String owner,
    String repo,
    dynamic workflowId, {
    required String ref,
    Map<String, dynamic>? inputs,
  }) async {
    try {
      await _dio.post(
        '/repos/$owner/$repo/actions/workflows/$workflowId/dispatches',
        data: {
          'ref': ref,
          if (inputs != null) 'inputs': inputs,
        },
      );
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Get jobs for a workflow run (GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs)
  Future<Map<String, dynamic>> getWorkflowRunJobs(String owner, String repo, dynamic runId) async {
    try {
      final response = await _dio.get('/repos/$owner/$repo/actions/runs/$runId/jobs');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Get logs for a specific job (GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs)
  Future<String> getJobLogs(String owner, String repo, dynamic jobId) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/actions/jobs/$jobId/logs',
        options: Options(responseType: ResponseType.plain),
      );
      return response.data.toString();
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Re-run a workflow run (POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun)
  Future<void> rerunWorkflow(String owner, String repo, dynamic runId) async {
    try {
      await _dio.post('/repos/$owner/$repo/actions/runs/$runId/rerun');
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Cancel a workflow run (POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel)
  Future<void> cancelWorkflow(String owner, String repo, dynamic runId) async {
    try {
      await _dio.post('/repos/$owner/$repo/actions/runs/$runId/cancel');
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Get detailed file metadata including content, SHA, etc.
  Future<Map<String, dynamic>> getFileDetails(String owner, String repo, String path, {String? ref}) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/contents/$path',
        queryParameters: {
          if (ref != null) 'ref': ref,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Create or update a file in a repository (PUT /repos/{owner}/{repo}/contents/{path})
  Future<Map<String, dynamic>> updateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String sha,
    required String message,
    required String branch,
  }) async {
    try {
      final base64Content = base64.encode(utf8.encode(content));
      final response = await _dio.put(
        '/repos/$owner/$repo/contents/$path',
        data: {
          'message': message,
          'content': base64Content,
          'sha': sha,
          'branch': branch,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw GitHubApiException.fromDioError(e);
    }
  }

  /// Fetch a repository's Git tree recursively (GET /repos/{owner}/{repo}/git/trees/{tree_sha})
  Future<Map<String, dynamic>> getGitTree(String owner, String repo, {String treeSha = 'main', bool recursive = true}) async {
    try {
      final response = await _dio.get(
        '/repos/$owner/$repo/git/trees/$treeSha',
        queryParameters: {
          if (recursive) 'recursive': '1',
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // If 'main' fails, try 'master' as fallback
      if (treeSha == 'main') {
        return await getGitTree(owner, repo, treeSha: 'master', recursive: recursive);
      }
      throw GitHubApiException.fromDioError(e);
    }
  }
}
