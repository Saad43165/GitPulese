import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/history_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/state_views.dart';
import '../repo_detail/repo_detail_screen.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafePage(
        child: bookmarksAsync.when(
          data: (items) {
            if (items.isEmpty) {
            return const Column(
              children: [
                PageHeader(
                  title: 'Saved',
                  subtitle: 'Your starred repositories in one place',
                ),
                Expanded(
                  child: EmptyStateView(
                    icon: Icons.bookmark_border_rounded,
                    title: 'No saved repos yet',
                    subtitle: 'Tap the star on any repository to save it here',
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Saved',
                subtitle: '${items.length} ${items.length == 1 ? 'repository' : 'repositories'} bookmarked',
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear all saved',
                  onPressed: () => _confirmClearAll(context, ref),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    0,
                    AppSpacing.pageHorizontal,
                    100,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return AppSurface(
                      onTap: () {
                        final parts = (item['fullName'] as String).split('/');
                        if (parts.length == 2) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RepoDetailScreen(
                                owner: parts[0],
                                repoName: parts[1],
                              ),
                            ),
                          );
                        }
                      },
                      showAccentStripe: true,
                      accentColor: AppColors.star,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: CachedNetworkImage(
                              imageUrl: item['avatarUrl'] as String? ?? '',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['fullName'] as String,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                ),
                                if ((item['description'] as String?)?.isNotEmpty == true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item['description'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                              const SizedBox(width: 4),
                              Text(
                                formatCount(item['stars'] as int? ?? 0),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Column(
          children: [
            PageHeader(title: 'Saved', subtitle: 'Loading your bookmarks…'),
            Expanded(child: ShimmerList()),
          ],
        ),
        error: (e, _) => Column(
          children: [
            const PageHeader(title: 'Saved'),
            Expanded(
              child: ErrorStateView(
                message: e.toString(),
                onRetry: () => ref.invalidate(bookmarksProvider),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all saved repos?'),
        content: const Text('This removes every bookmarked repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(bookmarkActionsProvider).clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved repos cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
