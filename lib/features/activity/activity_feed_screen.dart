import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';

final userEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserEvents(username);
});

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(userEventsProvider(username));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity Feed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text('@$username', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('No recent activity found.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userEventsProvider(username));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.md),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventTimelineItem(context, event, isDark, isLast: index == events.length - 1);
              },
            ),
          );
        },
        loading: () => const Center(child: GlowingIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is GitHubApiException ? e.message : e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(userEventsProvider(username)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTimelineItem(BuildContext context, Map<String, dynamic> event, bool isDark, {required bool isLast}) {
    final type = event['type'] as String? ?? 'UnknownEvent';
    final repoMap = event['repo'] as Map<String, dynamic>?;
    final repoName = repoMap?['name'] as String? ?? 'Unknown';
    final payload = event['payload'] as Map<String, dynamic>?;
    final createdAtStr = event['created_at'] as String?;
    final date = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    
    IconData icon;
    Color color;
    String description;
    String? details;

    switch (type) {
      case 'WatchEvent':
        icon = Icons.star_rounded;
        color = AppColors.star;
        description = 'Starred a repository';
        break;
      case 'PushEvent':
        icon = Icons.file_upload_rounded;
        color = const Color(0xFF10B981);
        description = 'Pushed to repository';
        final commits = payload?['commits'] as List<dynamic>?;
        if (commits != null && commits.isNotEmpty) {
          details = '${commits.length} commit(s). Latest: ${commits.first['message']}';
        }
        break;
      case 'CreateEvent':
        icon = Icons.add_circle_outline_rounded;
        color = const Color(0xFF3B82F6);
        final refType = payload?['ref_type'] as String? ?? 'repository';
        description = 'Created $refType';
        break;
      case 'ForkEvent':
        icon = Icons.call_split_rounded;
        color = const Color(0xFF8B5CF6);
        description = 'Forked repository';
        break;
      case 'IssuesEvent':
        icon = Icons.error_outline_rounded;
        color = AppColors.danger;
        final action = payload?['action'] as String? ?? 'opened';
        description = '${action.toUpperCase()} an issue';
        final issue = payload?['issue'] as Map<String, dynamic>?;
        if (issue != null) {
          details = issue['title'];
        }
        break;
      case 'PullRequestEvent':
        icon = Icons.merge_type_rounded;
        color = const Color(0xFFF59E0B);
        final action = payload?['action'] as String? ?? 'opened';
        description = '${action.toUpperCase()} a pull request';
        final pr = payload?['pull_request'] as Map<String, dynamic>?;
        if (pr != null) {
          details = pr['title'];
        }
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.grey;
        description = type.replaceAll('Event', '');
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                )
              else 
                const SizedBox(height: 24), // padding for last item
            ],
          ),
          const SizedBox(width: 16),
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      if (date != null)
                        Text(
                          timeago.format(date),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      launchUrl(Uri.parse('https://github.com/$repoName'), mode: LaunchMode.externalApplication);
                    },
                    child: Text(
                      repoName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      details,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
