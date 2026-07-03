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
                  Icon(Icons.commit_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Recent Commits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: commits.length > 3 ? 3 : commits.length,
                itemBuilder: (context, i) {
                  final commit = commits[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: InkWell(
                      onTap: () {
                        if (commit.htmlUrl.isNotEmpty) {
                          launchUrl(Uri.parse(commit.htmlUrl), mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
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
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.black26 : Colors.black12,
                                  ),
                                  child: commit.authorAvatarUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(commit.authorAvatarUrl!, fit: BoxFit.cover),
                                        )
                                      : Icon(Icons.person, size: 14, color: AppColors.accent),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    commit.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeago.format(commit.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (commits.length > 3) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (ctx) => DraggableScrollableSheet(
                          initialChildSize: 0.7,
                          minChildSize: 0.5,
                          maxChildSize: 0.95,
                          expand: false,
                          builder: (_, scrollController) => Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(Icons.commit_rounded, color: AppColors.accent),
                                    const SizedBox(width: 12),
                                    Text('All Recent Commits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: commits.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                                  itemBuilder: (context, i) {
                                    final commit = commits[i];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isDark ? Colors.black26 : Colors.black12,
                                        backgroundImage: commit.authorAvatarUrl != null ? NetworkImage(commit.authorAvatarUrl!) : null,
                                        child: commit.authorAvatarUrl == null ? Icon(Icons.person, size: 20, color: AppColors.accent) : null,
                                      ),
                                      title: Text(commit.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${commit.authorName} • ${timeago.format(commit.date)}', style: const TextStyle(fontSize: 13)),
                                      ),
                                      onTap: () {
                                        if (commit.htmlUrl.isNotEmpty) launchUrl(Uri.parse(commit.htmlUrl), mode: LaunchMode.externalApplication);
                                      }
                                    );
                                  }
                                )
                              )
                            ]
                          )
                        )
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View all commits', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: GlowingIndicator(size: 24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
