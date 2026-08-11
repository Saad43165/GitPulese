import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/repo_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/glowing_indicator.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

final discoveryCategoryProvider = StateProvider<String>((ref) => 'For You');

/// Derives the user's top languages from their own repos, then fetches
/// trending repos in those languages for a personalised feed.
final _userTopLanguagesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  final authUser = ref.watch(authenticatedUserProvider).valueOrNull;
  if (authUser == null) return [];
  try {
    final repos = await api.getUserRepos(authUser.login, perPage: 50);
    final counts = <String, int>{};
    for (final r in repos) {
      final lang = r.language;
      if (lang != null && lang.isNotEmpty) counts[lang] = (counts[lang] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  } catch (_) {
    return [];
  }
});

final discoveryFeedProvider = FutureProvider.autoDispose<List<GhRepo>>((ref) async {
  final category = ref.watch(discoveryCategoryProvider);
  final api = ref.watch(githubApiServiceProvider);

  String query;
  if (category == 'For You') {
    final langs = await ref.watch(_userTopLanguagesProvider.future);
    if (langs.isEmpty) {
      query = 'stars:>2000';
    } else {
      final langQuery = langs.map((l) => 'language:$l').join(' ');
      query = '$langQuery stars:>500';
    }
  } else if (category == 'Flutter') {
    query = 'topic:flutter stars:>500';
  } else if (category == 'AI & ML') {
    query = 'topic:machine-learning stars:>1000';
  } else if (category == 'Python') {
    query = 'language:python stars:>1500';
  } else if (category == 'Rust') {
    query = 'language:rust stars:>1000';
  } else if (category == 'Go') {
    query = 'language:go stars:>1000';
  } else if (category == 'TypeScript') {
    query = 'language:typescript stars:>1500';
  } else {
    query = 'stars:>2000';
  }

  final result = await api.searchRepositories(query: query, perPage: 25);
  final items = List<GhRepo>.from(result.items);
  items.shuffle();
  return items;
});

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  late PageController _pageController;
  final GlobalKey _swipeKey = GlobalKey();
  bool _tutorialTriggered = false;

  final List<String> _categories = [
    'For You',
    'Flutter',
    'AI & ML',
    'Python',
    'Rust',
    'Go',
    'TypeScript',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
  }

  void _checkAndShowTutorial() async {
    if (_tutorialTriggered) return;
    _tutorialTriggered = true;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_discovery_swipe') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ShowcaseView.get().startShowCase([_swipeKey]);
        await prefs.setBool('seen_discovery_swipe', true);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(selectedNavTabProvider);
    if (tabIndex == 2) {
      _checkAndShowTutorial();
    }

    final feedAsync = ref.watch(discoveryFeedProvider);
    final currentCategory = ref.watch(discoveryCategoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Feed Body wrapped in AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: feedAsync.when(
              data: (repos) {
                if (repos.isEmpty) {
                  return const Center(
                    key: ValueKey('empty_state'),
                    child: Text('No repositories found for this category'),
                  );
                }

                return RefreshIndicator(
                  key: const ValueKey('feed_data'),
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(discoveryFeedProvider);
                    await Future.delayed(const Duration(milliseconds: 600));
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    onPageChanged: (_) => HapticFeedback.selectionClick(),
                    itemBuilder: (context, index) {
                      final repo = repos[index % repos.length];
                      
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = _pageController.page! - index;
                            value = (1 - (value.abs() * 0.12)).clamp(0.0, 1.0);
                          } else {
                            if (index != 0) value = 0.88;
                          }
                          final opacity = Curves.easeOut.transform(value);
                          if (opacity <= 0.01) return const SizedBox.shrink();

                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: value,
                              alignment: Alignment.center,
                              child: child,
                            ),
                          );
                        },
                        child: RepaintBoundary(
                          child: _DiscoveryCard(repo: repo),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                key: ValueKey('loading_state'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlowingIndicator(size: 32),
                    SizedBox(height: 16),
                    Text(
                      'Curating discovery feed...', 
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              error: (e, _) => Center(
                key: ValueKey('error_state'),
                child: Text('Failed to load feed: $e'),
              ),
            ),
          ),

          // Top Glassmorphic Header & Category Filter Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 46, 16, 12),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkBg : Colors.white).withValues(alpha: 0.9),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Discover',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          _AnimatedRefreshButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              ref.invalidate(discoveryFeedProvider);
                              await Future.delayed(const Duration(milliseconds: 600));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Category Filter Pills (Distinct contrast)
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = _categories[i];
                            final isSelected = currentCategory == cat;

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(discoveryCategoryProvider.notifier).state = cat;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent
                                      : (isDark
                                          ? AppColors.darkSurfaceElevated
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accent
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (cat == 'For You') ...[
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 12,
                                        color: isSelected ? Colors.white : AppColors.accent,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Swipe Guide Hint Overlay
          Positioned(
            bottom: 95,
            left: 0,
            right: 0,
            child: Showcase(
              key: _swipeKey,
              title: 'Infinite Discovery Swipe',
              description: 'Swipe vertically (up/down) to discover trending GitHub repositories.',
              titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
              tooltipBackgroundColor: AppColors.darkSurfaceElevated,
              tooltipBorderRadius: BorderRadius.circular(12),
              blurValue: 2,
              child: const IgnorePointer(
                child: Column(
                  children: [
                    Icon(Icons.keyboard_double_arrow_up_rounded, color: AppColors.accent, size: 28),
                    SizedBox(height: 2),
                    Text(
                      'SWIPE UP',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedRefreshButton extends StatefulWidget {
  const _AnimatedRefreshButton({required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  State<_AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<_AnimatedRefreshButton> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _triggerRefresh() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _rotationController.repeat();
    
    await widget.onPressed();
    
    if (mounted) {
      _rotationController.stop();
      await _rotationController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
      _rotationController.reset();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: IconButton(
            icon: RotationTransition(
              turns: _rotationController,
              child: Icon(
                Icons.shuffle_rounded, 
                color: AppColors.accent,
                size: 18,
              ),
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkSurfaceElevated.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: _triggerRefresh,
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCard extends ConsumerWidget {
  const _DiscoveryCard({required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = ref.watch(isBookmarkedProvider(repo.id)).valueOrNull ?? false;

    final sizeStr = repo.size >= 1024 
        ? '${(repo.size / 1024).toStringAsFixed(1)} MB' 
        : '${repo.size} KB';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 134, 16, 85),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: repo.owner.avatarUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${repo.owner.login}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repo.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (repo.language != null) ...[
                      _buildTag(Icons.code_rounded, repo.language!, AppColors.accent),
                      const SizedBox(width: 6),
                    ],
                    _buildTag(Icons.star_rounded, formatCount(repo.stargazersCount), const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    _buildTag(
                      Icons.favorite_rounded,
                      '${repo.healthLabel} (${repo.healthScore})',
                      repo.healthScore >= 75 
                          ? AppColors.success 
                          : (repo.healthScore >= 55 ? AppColors.warning : AppColors.danger),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.description ?? 'No description provided.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    
                    if (repo.topics.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: repo.topics.take(4).map((topic) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '#$topic',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sd_storage_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                sizeStr,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.gavel_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                repo.license?.spdxId ?? repo.license?.name ?? 'No License',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                timeago.format(repo.pushedAt),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(bookmarkActionsProvider).toggle(repo);
                      },
                      icon: Icon(
                        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 18,
                        color: isBookmarked ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      label: Text(
                        isBookmarked ? 'Saved' : 'Save',
                        style: TextStyle(
                          color: isBookmarked ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isBookmarked 
                              ? AppColors.accent.withValues(alpha: 0.5) 
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.push(AppRoutes.repoPath(repo.owner.login, repo.name));
                      },
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text(
                        'Explore', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
