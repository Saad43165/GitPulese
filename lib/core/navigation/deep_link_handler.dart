import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

/// Singleton navigator key — injected into MaterialApp.router so we can
/// navigate from outside the widget tree (e.g. notification tap callbacks).
final navigatorKey = GlobalKey<NavigatorState>();

/// Parses a GitHub API subject URL (from a notification payload) and
/// navigates to the appropriate in-app screen.
///
/// Subject URL formats:
///   Issue      → https://api.github.com/repos/{owner}/{repo}/issues/{n}
///   PullRequest→ https://api.github.com/repos/{owner}/{repo}/pulls/{n}
///   Release    → https://api.github.com/repos/{owner}/{repo}/releases/{n}
///   Commit     → https://api.github.com/repos/{owner}/{repo}/commits/{sha}
///   Discussion → https://api.github.com/repos/{owner}/{repo}/discussions/{n}
class DeepLinkHandler {
  DeepLinkHandler._();

  /// Called from the notification tap callback. payload is JSON:
  /// {"url": "...", "type": "Issue|PullRequest|...", "repo": "owner/repo", "title": "..."}
  static void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      final url = data['url'] as String?;
      final type = data['type'] as String?;
      final repo = data['repo'] as String?; // "owner/repo"
      final title = data['title'] as String? ?? '';

      if (url == null || type == null || repo == null) return;

      final parts = repo.split('/');
      if (parts.length != 2) return;
      final owner = parts[0];
      final repoName = parts[1];

      final context = navigatorKey.currentContext;
      if (context == null) return;

      switch (type) {
        case 'Issue':
          final number = _extractNumber(url);
          if (number != null) {
            context.push(AppRoutes.issueDetailPath(owner, repoName, number, title));
          } else {
            context.push(AppRoutes.issuesPath(owner, repoName));
          }
          break;

        case 'PullRequest':
          final number = _extractNumber(url);
          if (number != null) {
            context.push(AppRoutes.prPath(owner, repoName, number, title));
          } else {
            context.push(AppRoutes.pullsPath(owner, repoName));
          }
          break;

        case 'Release':
        case 'Commit':
        case 'Discussion':
        case 'CheckSuite':
        case 'WorkflowRun':
          // Navigate to repo — best we can do for these types.
          context.push(AppRoutes.repoPath(owner, repoName));
          break;

        default:
          // Unknown type — go to notifications hub.
          context.go(AppRoutes.notifications);
          break;
      }
    } catch (_) {
      // Malformed payload — silently ignore rather than crash.
    }
  }

  static int? _extractNumber(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }

  /// Builds the JSON payload string to embed in a notification.
  static String buildPayload({
    required String subjectUrl,
    required String type,
    required String repoFullName,
    required String title,
  }) {
    return json.encode({
      'url': subjectUrl,
      'type': type,
      'repo': repoFullName,
      'title': title,
    });
  }
}
