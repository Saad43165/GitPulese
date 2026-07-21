import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/history_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../../widgets/safe_page.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: bookmarksAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    leading: const AppBackButton(),
                    title: const Text('Saved Items'),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    centerTitle: true,
                  ),
                  const SliverFillRemaining(
                    child: EmptyStateView(
                      icon: Icons.bookmark_border_rounded,
                      title: 'No saved repos yet',
                      subtitle: 'Tap the star on any repository to save it here',
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  leading: const AppBackButton(),
                  title: const Text('Saved Items'),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  pinned: true,
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      tooltip: 'Clear all',
                      color: AppColors.danger,
                      onPressed: () => _confirmClearAll(context, ref),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'repository' : 'repositories'} bookmarked',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = items[i];
                        final compactCards = ref.watch(compactCardsProvider);
                        final parts = (item['fullName'] as String).split('/');
                        final repoName = parts.length == 2 ? parts[1] : item['fullName'] as String;
                        final owner = parts.length == 2 ? parts[0] : '';
                        final language = item['language'] as String?;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AppSurface(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (parts.length == 2) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RepoDetailScreen(
                                      owner: owner,
                                      repoName: repoName,
                                    ),
                                  ),
                                );
                              }
                            },
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: compactCards ? 12 : 16,
                            ),
                            showAccentStripe: true,
                            accentColor: AppColors.star,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: CachedNetworkImage(
                                              imageUrl: item['avatarUrl'] as String? ?? '',
                                              width: 16,
                                              height: 16,
                                              errorWidget: (_, __, ___) => const Icon(Icons.source_rounded, size: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              owner,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white54 : Colors.black54,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        repoName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (item['description'] != null && (item['description'] as String).isNotEmpty && !compactCards) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          item['description'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ],
                                      if (language != null && language.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: AppColors.colorForLanguage(language),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              language,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatCount(item['stars'] as int? ?? 0),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => CustomScrollView(
            slivers: [
              const SliverAppBar(
                leading: AppBackButton(),
                title: Text('Saved Items'),
                elevation: 0,
                backgroundColor: Colors.transparent,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: const ShimmerListCard(),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
            ],
          ),
          error: (e, _) => CustomScrollView(
            slivers: [
              const SliverAppBar(
                leading: AppBackButton(),
                title: Text('Saved Items'),
                elevation: 0,
                backgroundColor: Colors.transparent,
                centerTitle: true,
              ),
              SliverFillRemaining(
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
        content: const Text('This removes every bookmarked repository from your local list.'),
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
