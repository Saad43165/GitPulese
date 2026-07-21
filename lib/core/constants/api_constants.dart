/// Central place for all GitHub API endpoint and config constants.
class ApiConstants {
  ApiConstants._();

  /// URL of your deployed backend proxy (see /gitexplorer-backend README).
  /// Replace this with your real Render/Railway URL before shipping —
  /// leaving it as-is will make every network call fail.
  static const String backendBaseUrl = 'https://gitpulse-ai.gitpulse-ai.workers.dev';

  static const String baseUrl = 'https://api.github.com';

  // Search endpoints
  static const String searchRepos = '/search/repositories';
  static const String searchCode = '/search/code';
  static const String searchUsers = '/search/users';
  static const String searchIssues = '/search/issues';
  static const String searchTopics = '/search/topics';

  // Repo endpoints
  static String repoDetail(String owner, String repo) => '/repos/$owner/$repo';
  static String repoReadme(String owner, String repo) =>
      '/repos/$owner/$repo/readme';
  static String repoLanguages(String owner, String repo) =>
      '/repos/$owner/$repo/languages';
  static String repoContributors(String owner, String repo) =>
      '/repos/$owner/$repo/contributors';
  static String repoReleases(String owner, String repo) =>
      '/repos/$owner/$repo/releases';
  static String repoCommits(String owner, String repo) =>
      '/repos/$owner/$repo/commits';

  // User endpoints
  static String userDetail(String username) => '/users/$username';
  static String userRepos(String username) => '/users/$username/repos';

  // Rate limit
  static const String rateLimit = '/rate_limit';

  static const int defaultPerPage = 25;
  static const Duration requestTimeout = Duration(seconds: 20);

  // Secure storage key for the user's personal access token
  static const String patStorageKey = 'gh_pat_token';
  static const String groqKeyStorageKey = 'groq_api_key';
}
