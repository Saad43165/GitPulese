import 'package:gitexplorer/core/network/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/history_providers.dart';
import '../../providers/search_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/page_header.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/staggered_fade_item.dart';
import '../../widgets/state_views.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../user_detail/user_detail_screen.dart';
import 'widgets/code_result_tile.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/issue_tile.dart';
import 'widgets/user_result_tile.dart';
import '../../widgets/shimmer_skeletons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _searchTabsKey = GlobalKey();
  bool _tutorialTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  void _checkAndShowTutorial() async {
    if (_tutorialTriggered) return;
    _tutorialTriggered = true;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_search_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _searchBarKey,
          _filterButtonKey,
          _searchTabsKey,
        ]);
        await prefs.setBool('seen_search_tutorial', true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = q;

    final tab = ref.read(searchTabProvider);
    final type = switch (tab) {
      SearchTab.repositories => 'search_repo',
      SearchTab.code => 'search_code',
      SearchTab.users => 'search_user',
      SearchTab.issues => 'search_issue',
    };
    ref.read(historyActionsProvider).logSearch(type: type, query: q);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(selectedNavTabProvider);
    if (tabIndex == 1) { // 1 is Search screen index
      _checkAndShowTutorial();
    }

    final tab = ref.watch(searchTabProvider);
    final filters = ref.watch(searchFiltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Discover',
            subtitle: 'Search millions of repos, users, and code snippets',
          ),
          
          // PREMIUM GLASSMORPHIC SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Row(
              children: [
                Expanded(
                  child: Showcase(
                    key: _searchBarKey,
                    title: 'Global Search Input',
                    description: 'Search globally. Simply type keywords and tap Enter or search on your keyboard to request GitHub results.',
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    tooltipBackgroundColor: const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    blurValue: 2,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submit,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search GitHub...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(AdaptiveIcons.search, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 18),
                                  onPressed: () {
                                    _controller.clear();
                                    ref.read(searchQueryProvider.notifier).state = '';
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      if (mounted) {
                                        _focusNode.unfocus();
                                      }
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // GLOWING FILTER BUTTON
                Showcase(
                  key: _filterButtonKey,
                  title: 'Search Filters',
                  description: 'Narrow down repository queries by specifying primary language constraints, minimum stars count, or fork levels.',
                  titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  tooltipBackgroundColor: const Color(0xFF1E293B),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  blurValue: 2,
                  child: GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FilterSheet(),
                    ),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(AdaptiveIcons.filter, color: Colors.white, size: 20),
                          if (filters.activeCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${filters.activeCount}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // CUSTOM GLOWING PILL TABS
          Showcase(
            key: _searchTabsKey,
            title: 'Search Category Scopes',
            description: 'Quickly switch search scopes between Repositories, Users/Developers, specific Code blocks, or Issue tickets.',
            titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
            tooltipBackgroundColor: const Color(0xFF1E293B),
            tooltipBorderRadius: BorderRadius.circular(12),
            blurValue: 2,
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                children: [
                  _buildTab(SearchTab.repositories, 'Repositories', Icons.folder_rounded, tab),
                  const SizedBox(width: 8),
                  _buildTab(SearchTab.users, 'Users', Icons.person_rounded, tab),
                  const SizedBox(width: 8),
                  _buildTab(SearchTab.code, 'Code', Icons.code_rounded, tab),
                  const SizedBox(width: 8),
                  _buildTab(SearchTab.issues, 'Issues', Icons.bug_report_rounded, tab),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // RESULTS VIEW
          Expanded(
            child: ref.watch(searchQueryProvider).isEmpty
                ? _RecentSearchesView(
                    onSelect: (q) {
                      _controller.text = q;
                      _submit(q);
                    },
                  )
                : switch (tab) {
                    SearchTab.repositories => const _RepoResultsView(),
                    SearchTab.code => const _CodeResultsView(),
                    SearchTab.users => const _UserResultsView(),
                    SearchTab.issues => const _IssueResultsView(),
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(SearchTab value, String label, IconData icon, SearchTab currentTab) {
    final isSelected = value == currentTab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        if (ref.read(searchTabProvider) == value) return;
        ref.read(searchTabProvider.notifier).state = value;
        final currentQuery = ref.read(searchQueryProvider);
        if (currentQuery.isNotEmpty) {
          ref.read(searchQueryProvider.notifier).state = '';
          Future.microtask(() {
            if (mounted) {
              ref.read(searchQueryProvider.notifier).state = currentQuery;
            }
          });
        } else if (_controller.text.trim().isNotEmpty) {
          _submit(_controller.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              size: 14, 
              color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchesView extends ConsumerWidget {
  final ValueChanged<String> onSelect;
  const _RecentSearchesView({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return historyAsync.when(
      data: (items) {
        final uniqueSearches = <String, String>{};
        for (var item in items.where((e) => e.type.startsWith('search_'))) {
          final query = item.query.trim();
          final lower = query.toLowerCase();
          if (!uniqueSearches.containsKey(lower)) {
            uniqueSearches[lower] = query;
          }
        }
        final searches = uniqueSearches.values.toList();

        if (searches.isEmpty) {
          final presetPicks = [
            'machine learning', 'flutter ui', 'react native', 
            'linux kernel', 'rust web', 'ios development'
          ];
          
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.lg),
            children: [
              const EmptyStateView(
                icon: Icons.travel_explore_rounded,
                title: 'Explore the universe',
                subtitle: 'Tap a trending topic or search above to begin',
              ),
              const SizedBox(height: 32),
              Text(
                'Trending Topics 🔥',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetPicks.map((q) => GestureDetector(
                  onTap: () => onSelect(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 14, color: AppColors.accentSoft),
                        const SizedBox(width: 6),
                        Text(
                          q,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.lg),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    for (var item in items.where((e) => e.type.startsWith('search_'))) {
                      ref.read(historyActionsProvider).deleteEntry(item.id!);
                    }
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: searches.map((q) => GestureDetector(
                onTap: () => onSelect(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 6),
                      Text(
                        q,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RepoResultsView extends ConsumerWidget {
  const _RepoResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(repoSearchProvider);

    if (query.isEmpty) {
      return const EmptyStateView(
        icon: Icons.travel_explore_rounded,
        title: 'Explore the universe',
        subtitle: 'Search "machine learning", "flutter", or "react"',
      );
    }

    return results.when(
      data: (res) {
        if (res == null || res.items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.search_off_rounded,
            title: 'No repositories found',
            subtitle: 'Try a different search term',
          );
        }
        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              100,
            ),
            itemCount: res.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, i) {
              final repo = res.items[i];
              return StaggeredFadeItem(
                index: i,
                child: RepoCard(
                  repo: repo,
                  compact: ref.watch(compactCardsProvider),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RepoDetailScreen(
                        owner: repo.owner.login,
                        repoName: repo.name,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const ShimmerListCards(),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(repoSearchProvider),
      ),
    );
  }
}

class _CodeResultsView extends ConsumerWidget {
  const _CodeResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(codeSearchProvider);

    if (query.isEmpty) {
      return const EmptyStateView(
        icon: Icons.code_rounded,
        title: 'Code Search',
        subtitle: 'Find functions, classes, and exact matches',
      );
    }

    return results.when(
      data: (res) {
        if (res == null || res.items.isEmpty) {
          return const EmptyStateView(icon: Icons.search_off_rounded, title: 'No code matches found');
        }
        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              100,
            ),
            itemCount: res.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => StaggeredFadeItem(
              index: i,
              child: CodeResultTile(result: res.items[i]),
            ),
          ),
        );
      },
      loading: () => const ShimmerListCards(),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(codeSearchProvider),
      ),
    );
  }
}

class _UserResultsView extends ConsumerWidget {
  const _UserResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(userSearchProvider);

    if (query.isEmpty) {
      return const EmptyStateView(
        icon: Icons.people_alt_rounded,
        title: 'Find developers',
        subtitle: 'Search for developers, teams, and organizations',
      );
    }

    return results.when(
      data: (res) {
        if (res == null || res.items.isEmpty) {
          return const EmptyStateView(icon: Icons.search_off_rounded, title: 'No users found');
        }
        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              100,
            ),
            itemCount: res.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => StaggeredFadeItem(
              index: i,
              child: UserResultTile(
                user: res.items[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserDetailScreen(username: res.items[i].login),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const ShimmerListCards(),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(userSearchProvider),
      ),
    );
  }
}

class _IssueResultsView extends ConsumerWidget {
  const _IssueResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(issueSearchProvider);

    if (query.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bug_report_rounded,
        title: 'Issues & PRs',
        subtitle: 'Search for bugs, features, and pull requests',
      );
    }

    return results.when(
      data: (res) {
        if (res == null || res.items.isEmpty) {
          return const EmptyStateView(icon: Icons.search_off_rounded, title: 'No issues found');
        }
        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              100,
            ),
            itemCount: res.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => StaggeredFadeItem(
              index: i,
              child: IssueTile(issue: res.items[i]),
            ),
          ),
        );
      },
      loading: () => const ShimmerListCards(),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(issueSearchProvider),
      ),
    );
  }
}
