import 'package:gitexplorer/core/network/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/history_providers.dart';
import '../../providers/search_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
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
    final tab = ref.watch(searchTabProvider);
    final filters = ref.watch(searchFiltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
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
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(8),
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
                                  _focusNode.unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // GLOWING FILTER BUTTON
                GestureDetector(
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
                      borderRadius: BorderRadius.circular(8),
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
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // CUSTOM GLOWING PILL TABS
          SizedBox(
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
      onTap: () => ref.read(searchTabProvider.notifier).state = value,
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
        final searches = items
            .where((e) => e.type.startsWith('search_'))
            .map((e) => e.query)
            .toSet()
            .toList();

        if (searches.isEmpty) {
          return const EmptyStateView(
            icon: Icons.travel_explore_rounded,
            title: 'Explore the universe',
            subtitle: 'Search "machine learning", "flutter", or "react"',
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
