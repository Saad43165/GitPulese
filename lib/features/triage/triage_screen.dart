import 'package:gitexplorer/core/network/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/github_api_service.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';

enum TriageFilter { allOpenIssues, allOpenPRs }

final triageFilterProvider = StateProvider.autoDispose<TriageFilter>((ref) => TriageFilter.allOpenIssues);

final triageResultProvider = FutureProvider.autoDispose
    .family<SearchIssuesResult, ({String owner, String repo})>((ref, args) async {
  final filter = ref.watch(triageFilterProvider);
  final api = ref.watch(githubApiServiceProvider);
  return api.searchIssues(
    query: 'repo:${args.owner}/${args.repo}',
    pullRequestsOnly: filter == TriageFilter.allOpenPRs,
    state: 'open',
    perPage: 50,
  );
});

class TriageScreen extends ConsumerWidget {
  const TriageScreen({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(triageFilterProvider);
    final args = (owner: owner, repo: repoName);
    final resultAsync = ref.watch(triageResultProvider(args));

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('$owner/$repoName')),
        body: SafeArea(
          top: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Maintainer Triage',
              subtitle: 'Oldest open items first — spot what needs attention',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: SegmentedButton<TriageFilter>(
                segments: const [
                  ButtonSegment(value: TriageFilter.allOpenIssues, label: Text('Issues')),
                  ButtonSegment(value: TriageFilter.allOpenPRs, label: Text('Pull Requests')),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(triageFilterProvider.notifier).state = s.first,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: resultAsync.when(
                data: (result) {
                  if (result.items.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.task_alt_rounded,
                      title: 'Queue is clear',
                      subtitle: 'No open issues or pull requests right now',
                    );
                  }
                  final sorted = [...result.items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      0,
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxl,
                    ),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final issue = sorted[i];
                      final ageDays = DateTime.now().difference(issue.createdAt).inDays;
                      final isStale = ageDays > 90;
                      final accent = isStale ? AppColors.danger : AppColors.accent;

                      return AppSurface(
                        onTap: () => launchUrl(
                          Uri.parse(issue.htmlUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        showAccentStripe: true,
                        accentColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isStale)
                                  Container(
                                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    ),
                                    child: const Text(
                                      'STALE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    '#${issue.number} ${issue.title}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Text(
                                  'Opened ${timeago.format(issue.createdAt)}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: isStale
                                            ? AppColors.danger
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${issue.comments}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const ShimmerList(),
                error: (e, _) => ErrorStateView(
                  message: e is GitHubApiException ? e.message : e.toString(),
                  onRetry: () => ref.invalidate(triageResultProvider(args)),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
