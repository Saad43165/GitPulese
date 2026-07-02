import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/glowing_indicator.dart';

class RecentCommitsSection extends ConsumerWidget {
  const RecentCommitsSection({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitsAsync = ref.watch(repoCommitsProvider((owner: owner, repo: repoName)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return commitsAsync.when(
      data: (commits) {
        if (commits.isEmpty) return const SizedBox.shrink();

        return AppSurface(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Recent Commits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: commits.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Container(
                    height: 20,
                    width: 2,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  ),
                ),
                itemBuilder: (context, i) {
                  final commit = commits[i];
                  return InkWell(
                    onTap: () {
                      if (commit.htmlUrl.isNotEmpty) {
                        launchUrl(Uri.parse(commit.htmlUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: commit.authorAvatarUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(commit.authorAvatarUrl!, fit: BoxFit.cover),
                                )
                              : Icon(Icons.person_outline, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                commit.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    commit.authorName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '•',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black26),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeago.format(commit.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: GlowingIndicator(size: 24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
