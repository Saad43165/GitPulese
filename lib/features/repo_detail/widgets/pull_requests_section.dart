import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../providers/repo_detail_providers.dart';
import '../../../../widgets/app_surface.dart';
import '../../../../widgets/glowing_indicator.dart';
import '../ai_pr_reader_screen.dart';

class PullRequestsSection extends ConsumerWidget {
  const PullRequestsSection({
    super.key,
    required this.owner,
    required this.repoName,
  });

  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(repoPullRequestsProvider((owner: owner, repo: repoName)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return prsAsync.when(
      data: (prs) {
        if (prs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No open pull requests found.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: prs.take(5).map((prData) {
            final pr = prData as dynamic;
            // Depending on the GhIssue model returned by searchIssues, properties might be accessible via getters
            final title = pr.title as String;
            final number = pr.number as int;
            final userLogin = pr.user?.login as String? ?? 'Unknown';
            final createdAt = pr.createdAt as DateTime?;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppSurface(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiPrReaderScreen(
                        owner: owner,
                        repoName: repoName,
                        pullNumber: number,
                        title: title,
                      ),
                    ),
                  );
                },
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.call_merge_rounded, color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#$number opened ${createdAt != null ? timeago.format(createdAt) : ''} by $userLogin',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 12),
                          SizedBox(width: 4),
                          Text('AI Read', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: GlowingIndicator(size: 24)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load pull requests: $e'),
      ),
    );
  }
}
