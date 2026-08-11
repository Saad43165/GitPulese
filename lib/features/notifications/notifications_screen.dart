import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/notifications/background_task_manager.dart';
import '../../core/notifications/github_notification_sync.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/safe_page.dart';
import '../../core/network/dio_client.dart';
import '../auth/auth_dialog.dart';

final _pushEnabledProvider = FutureProvider.autoDispose<bool>(
  (_) => GitHubNotificationSync.isEnabled(),
);

final notificationsFilterProvider = StateProvider<bool>((ref) => false); // false = unread, true = all

final githubNotificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final showAll = ref.watch(notificationsFilterProvider);
  final api = ref.watch(githubApiServiceProvider);
  return api.getNotifications(all: showAll);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pat = ref.watch(githubPatProvider);
    final isLoggedIn = pat != null && pat.isNotEmpty;
    final showAll = ref.watch(notificationsFilterProvider);
    final notificationsAsync = ref.watch(githubNotificationsProvider);

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Notifications Hub',
              subtitle: 'Stay updated on code mentions, review requests, and PRs',
            ),

            if (!isLoggedIn)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'GitHub Account Required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect your Personal Access Token to sync your live GitHub notification inbox.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const AuthDialog()),
                          icon: const Icon(Icons.key_rounded),
                          label: const Text('Connect PAT'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Filter Pills Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Unread Only'),
                          selected: !showAll,
                          onSelected: (val) => ref.read(notificationsFilterProvider.notifier).state = false,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('All Notifications'),
                          selected: showAll,
                          onSelected: (val) => ref.read(notificationsFilterProvider.notifier).state = true,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.done_all_rounded),
                          tooltip: 'Mark All Read',
                          onPressed: () async {
                            try {
                              await ref.read(githubApiServiceProvider).markAllNotificationsRead();
                              ref.invalidate(githubNotificationsProvider);
                            } catch (_) {}
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Notifications',
                          onPressed: () => ref.invalidate(githubNotificationsProvider),
                        ),
                        ref.watch(_pushEnabledProvider).when(
                          data: (enabled) => IconButton(
                            icon: Icon(
                              enabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                              color: enabled ? AppColors.accent : Colors.white38,
                            ),
                            tooltip: enabled ? 'Push notifications ON — tap to disable' : 'Push notifications OFF — tap to enable',
                            onPressed: () async {
                              await GitHubNotificationSync.setEnabled(!enabled);
                              ref.invalidate(_pushEnabledProvider);
                              if (!enabled) {
                                await BackgroundTaskManager.scheduleGitHubNotificationSync();
                              } else {
                                await BackgroundTaskManager.cancelGitHubNotificationSync();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(!enabled
                                      ? 'Push notifications enabled — you\'ll be notified every 15 min'
                                      : 'Push notifications disabled'),
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                            },
                          ),
                          loading: () => const SizedBox(width: 40),
                          error: (_, __) => const SizedBox(width: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: notificationsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'All caught up!',
                        subtitle: 'No pending unread notifications in your inbox',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(githubNotificationsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          AppSpacing.md,
                          AppSpacing.pageHorizontal,
                          100,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final subject = item['subject'] as Map<String, dynamic>? ?? {};
                          final repo = item['repository'] as Map<String, dynamic>? ?? {};
                          final type = subject['type'] as String? ?? 'Notification';
                          final title = subject['title'] as String? ?? 'No title';
                          final repoName = repo['full_name'] as String? ?? '';
                          final unread = item['unread'] as bool? ?? false;
                          final threadId = item['id'] as String? ?? '';

                          IconData icon = Icons.notifications_rounded;
                          Color iconColor = AppColors.accent;
                          if (type == 'PullRequest') {
                            icon = Icons.call_merge_rounded;
                            iconColor = Colors.purpleAccent;
                          } else if (type == 'Issue') {
                            icon = Icons.bug_report_rounded;
                            iconColor = Colors.green;
                          } else if (type == 'Release') {
                            icon = Icons.new_releases_rounded;
                            iconColor = Colors.amber;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: unread
                                  ? (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface)
                                  : (isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: unread
                                    ? AppColors.accent.withValues(alpha: 0.4)
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: unread ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withValues(alpha: 0.15),
                                child: Icon(icon, color: iconColor, size: 20),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$repoName • $type',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                              trailing: unread
                                  ? IconButton(
                                      icon: const Icon(Icons.mark_email_read_rounded, size: 20),
                                      tooltip: 'Mark as Read',
                                      onPressed: () async {
                                        if (threadId.isNotEmpty) {
                                          await ref.read(githubApiServiceProvider).markNotificationRead(threadId);
                                          ref.invalidate(githubNotificationsProvider);
                                        }
                                      },
                                    )
                                  : null,
                              onTap: () {
                                final htmlUrl = 'https://github.com/$repoName';
                                launchUrl(Uri.parse(htmlUrl), mode: LaunchMode.externalApplication);
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: GlowingIndicator(size: 32)),
                  error: (e, _) => ErrorStateView(
                    message: e is GitHubApiException ? e.message : e.toString(),
                    onRetry: () => ref.invalidate(githubNotificationsProvider),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
