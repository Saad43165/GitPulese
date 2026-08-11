import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/repo_model.dart';
import '../../data/models/user_and_search_models.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/root_shell.dart';
import '../../features/repo_detail/repo_detail_screen.dart';
import '../../features/user_detail/user_detail_screen.dart';
import '../../features/user_detail/developer_wrapped_screen.dart';
import '../../features/repo_detail/ai_pr_review_screen.dart';
import '../../features/repo_detail/ask_this_repo_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/tracked_repos/tracked_repos_screen.dart';
import '../../features/editor/ai_code_editor_screen.dart';
import '../../features/devops/devops_workflows_screen.dart';
import '../../features/gists/gists_screen.dart';
import '../../features/vault/offline_codebase_vault_screen.dart';
import '../../features/compare/compare_screen.dart';
import '../../features/activity/activity_feed_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/secure_keychain_screen.dart';
import '../../features/settings/widgets_configuration_screen.dart';
import '../../features/architecture/architecture_visualizer_screen.dart';
import '../../features/portfolio/portfolio_generator_screen.dart';
import '../../features/triage/triage_screen.dart';
import '../../features/help/developer_help_hub.dart';
import '../../features/repo_detail/file_viewer_screen.dart';
import '../../features/repo_detail/ai_pr_reader_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/issues/issues_screen.dart';
import '../../features/issues/issue_detail_screen.dart';
import '../../features/issues/create_issue_screen.dart';
import '../../features/pull_requests/pull_requests_screen.dart';
import '../../features/pull_requests/create_pr_screen.dart';
import '../../features/orgs/orgs_screen.dart';
import '../../features/file_browser/file_browser_screen.dart';

// Route path constants — use these everywhere instead of raw strings.
abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const repo = '/repo/:owner/:repoName';
  static const user = '/user/:username';
  static const file = '/file/:owner/:repoName';
  static const pr = '/pr/:owner/:repoName/:pullNumber';
  static const ask = '/ask/:owner/:repoName';
  static const notifications = '/notifications';
  static const bookmarks = '/bookmarks';
  static const tracked = '/tracked';
  static const editor = '/editor';
  static const prReview = '/pr-review';
  static const devops = '/devops';
  static const gists = '/gists';
  static const vault = '/vault';
  static const compare = '/compare';
  static const activity = '/activity/:username';
  static const wrapped = '/wrapped';
  static const settings = '/settings';
  static const keychain = '/keychain';
  static const widgetsConfig = '/widgets-config';
  static const architecture = '/architecture';
  static const portfolio = '/portfolio';
  static const triage = '/triage/:owner/:repoName';
  static const help = '/help';
  static const login = '/login';
  static const issues = '/issues/:owner/:repoName';
  static const issueDetail = '/issue/:owner/:repoName/:number';
  static const createIssue = '/create-issue/:owner/:repoName';
  static const pulls = '/pulls/:owner/:repoName';
  static const createPr = '/create-pr/:owner/:repoName';
  static const orgs = '/orgs';
  static const fileBrowser = '/browse/:owner/:repoName';

  // Helpers to build concrete paths with params filled in.
  static String repoPath(String owner, String repoName) => '/repo/$owner/$repoName';
  static String userPath(String username) => '/user/$username';
  static String filePath(String owner, String repoName, String path) =>
      '/file/$owner/$repoName?path=${Uri.encodeComponent(path)}';
  static String prPath(String owner, String repoName, int pullNumber, String title) =>
      '/pr/$owner/$repoName/$pullNumber?title=${Uri.encodeComponent(title)}';
  static String askPath(String owner, String repoName, {String? desc, String? lang}) {
    final q = [
      if (desc != null) 'desc=${Uri.encodeComponent(desc)}',
      if (lang != null) 'lang=${Uri.encodeComponent(lang)}',
    ].join('&');
    return '/ask/$owner/$repoName${q.isNotEmpty ? '?$q' : ''}';
  }
  static String devopsPath({String? owner, String? repoName}) {
    final q = [
      if (owner != null) 'owner=${Uri.encodeComponent(owner)}',
      if (repoName != null) 'repo=${Uri.encodeComponent(repoName)}',
    ].join('&');
    return '/devops${q.isNotEmpty ? '?$q' : ''}';
  }
  static String activityPath(String username) => '/activity/$username';
  static String triagePath(String owner, String repoName) => '/triage/$owner/$repoName';
  static String issuesPath(String owner, String repoName) => '/issues/$owner/$repoName';
  static String issueDetailPath(String owner, String repoName, int number, String title) =>
      '/issue/$owner/$repoName/$number?title=${Uri.encodeComponent(title)}';
  static String createIssuePath(String owner, String repoName) => '/create-issue/$owner/$repoName';
  static String pullsPath(String owner, String repoName) => '/pulls/$owner/$repoName';
  static String createPrPath(String owner, String repoName) => '/create-pr/$owner/$repoName';
  static String fileBrowserPath(String owner, String repoName, [String path = '']) {
    final base = '/browse/$owner/$repoName';
    return path.isEmpty ? base : '$base?path=${Uri.encodeComponent(path)}';
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const RootShell(),
      ),
      GoRoute(
        path: AppRoutes.repo,
        builder: (context, state) => RepoDetailScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.user,
        builder: (context, state) => UserDetailScreen(
          username: state.pathParameters['username']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.file,
        builder: (context, state) => FileViewerScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
          filePath: state.uri.queryParameters['path'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.pr,
        builder: (context, state) => AiPrReaderScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
          pullNumber: int.parse(state.pathParameters['pullNumber']!),
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.ask,
        builder: (context, state) => AskThisRepoScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
          description: state.uri.queryParameters['desc'],
          primaryLanguage: state.uri.queryParameters['lang'],
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookmarks,
        builder: (_, __) => const BookmarksScreen(),
      ),
      GoRoute(
        path: AppRoutes.tracked,
        builder: (_, __) => const TrackedReposScreen(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        builder: (_, __) => const AiCodeEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.prReview,
        builder: (_, __) => const AiPrReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.devops,
        builder: (context, state) => DevOpsWorkflowsScreen(
          owner: state.uri.queryParameters['owner'],
          repoName: state.uri.queryParameters['repo'],
        ),
      ),
      GoRoute(
        path: AppRoutes.gists,
        builder: (_, __) => const GistsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vault,
        builder: (_, __) => const OfflineCodebaseVaultScreen(),
      ),
      GoRoute(
        path: AppRoutes.compare,
        builder: (_, __) => const CompareScreen(),
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => ActivityFeedScreen(
          username: state.pathParameters['username']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.wrapped,
        builder: (context, state) {
          // DeveloperWrappedScreen takes complex objects — passed via extra.
          // Extra is a Map: {'user': GhUser, 'repos': List<GhRepo>}
          final extra = state.extra as Map<String, dynamic>?;
          final user = extra?['user'] as GhUser?;
          final repos = (extra?['repos'] as List?)?.cast<GhRepo>() ?? const [];
          if (user == null) {
            // Fallback if navigated to directly without extra (e.g. deep link)
            return const Scaffold(
              body: Center(child: Text('Open this page from a user profile.')),
            );
          }
          return DeveloperWrappedScreen(user: user, repos: repos);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.keychain,
        builder: (_, __) => const SecureKeychainScreen(),
      ),
      GoRoute(
        path: AppRoutes.widgetsConfig,
        builder: (_, __) => const WidgetsConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.architecture,
        builder: (_, __) => const ArchitectureVisualizerScreen(),
      ),
      GoRoute(
        path: AppRoutes.portfolio,
        builder: (_, __) => const PortfolioGeneratorScreen(),
      ),
      GoRoute(
        path: AppRoutes.triage,
        builder: (context, state) => TriageScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (_, __) => const DeveloperHelpHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.issues,
        builder: (context, state) => IssuesScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.issueDetail,
        builder: (context, state) => IssueDetailScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
          issueNumber: int.parse(state.pathParameters['number']!),
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.createIssue,
        builder: (context, state) => CreateIssueScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.pulls,
        builder: (context, state) => PullRequestsScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.createPr,
        builder: (context, state) => CreatePrScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.orgs,
        builder: (_, __) => const OrgsScreen(),
      ),
      GoRoute(
        path: AppRoutes.fileBrowser,
        builder: (context, state) => FileBrowserScreen(
          owner: state.pathParameters['owner']!,
          repoName: state.pathParameters['repoName']!,
          currentPath: state.uri.queryParameters['path'] ?? '',
        ),
      ),
    ],
  );
});
