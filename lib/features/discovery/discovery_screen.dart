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
import '../../widgets/glowing_indicator.dart';
import '../repo_detail/repo_detail_screen.dart';

final discoveryFeedProvider = FutureProvider.autoDispose<List<GhRepo>>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  final result = await api.searchRepositories(
    query: 'stars:>5000',
  );
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_discovery_swipe') ?? false;
      if (!seen && mounted) {
        ShowCaseWidget.of(context).startShowCase([_swipeKey]);
        await prefs.setBool('seen_discovery_swipe', true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoveryFeedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Feed Body wrapped in AnimatedSwitcher for seamless cross-fading
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            child: feedAsync.when(
              data: (repos) {
                if (repos.isEmpty) {
                  return const Center(
                    key: ValueKey('empty_state'),
                    child: Text('No repositories found'),
                  );
                }

                return RefreshIndicator(
                  key: const ValueKey('feed_data'),
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(discoveryFeedProvider);
                    await Future.delayed(const Duration(milliseconds: 800));
                  },
                  child: Scrollbar(
                    controller: _pageController,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      onPageChanged: (index) {
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (context, index) {
                        final repo = repos[index % repos.length];
                        
                        // Animated page transformer (cards scale down/fade out as they exit viewport)
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              // Scale down to 88% and fade out slightly
                              value = (1 - (value.abs() * 0.12)).clamp(0.0, 1.0);
                            } else {
                              if (index != 0) {
                                value = 0.88;
                              }
                            }
                            final opacity = Curves.easeOut.transform(value);
                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: value,
                                alignment: Alignment.center,
                                child: child,
                              ),
                            );
                          },
                          child: _DiscoveryCard(repo: repo),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const Center(
                key: ValueKey('loading_state'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlowingIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Curating your feed...', 
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
          
          // Swipe Guide Hint Overlay
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Showcase(
              key: _swipeKey,
              description: 'Swipe up for infinite discovery!',
              child: IgnorePointer(
                child: Column(
                  children: [
                    const Icon(Icons.keyboard_double_arrow_up_rounded, color: AppColors.accent, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'SWIPE UP',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Premium Animated Refresh Button (Top Right)
          Positioned(
            top: 48,
            right: 16,
            child: _AnimatedRefreshButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(discoveryFeedProvider);
                // Hold rotation for at least 800ms for visual polish
                await Future.delayed(const Duration(milliseconds: 800));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Custom Animated Refresh Button with rotation transitions
// -------------------------------------------------------------
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
    setState(() {
      _isLoading = true;
    });
    
    // Repeat spin during load
    _rotationController.repeat();
    
    await widget.onPressed();
    
    if (mounted) {
      _rotationController.stop();
      // Smoothly snap rotation back to center
      await _rotationController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
      _rotationController.reset();
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: IconButton(
              icon: RotationTransition(
                turns: _rotationController,
                child: Icon(
                  Icons.refresh_rounded, 
                  color: isDark ? Colors.white : AppColors.accent,
                  size: 22,
                ),
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xCC161B22) : const Color(0xCCFFFFFF),
                padding: const EdgeInsets.all(10),
              ),
              onPressed: _triggerRefresh,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Discovery Card Design
// -------------------------------------------------------------
class _DiscoveryCard extends ConsumerWidget {
  const _DiscoveryCard({required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = ref.watch(bookmarksProvider).when(
          data: (items) => items.any((r) => r['repoId'] == repo.id),
          loading: () => false,
          error: (_, __) => false,
        );

    final sizeStr = repo.size >= 1024 
        ? '${(repo.size / 1024).toStringAsFixed(1)} MB' 
        : '${repo.size} KB';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 64, 16, 110),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Ambient glow effect
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF9333EA).withValues(alpha: isDark ? 0.12 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: repo.owner.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${repo.owner.login}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repo.name,
                              style: const TextStyle(
                                fontSize: 21,
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
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repo.description ?? 'No description provided.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 5,
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
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  topic,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                            ),
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
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161C24) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem(Icons.fork_right_rounded, formatCount(repo.forksCount), 'Forks', AppColors.accent),
                              _buildMetricItem(Icons.visibility_rounded, formatCount(repo.watchersCount), 'Watchers', AppColors.success),
                              _buildMetricItem(Icons.error_outline_rounded, formatCount(repo.openIssuesCount), 'Issues', AppColors.warning),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
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
                            isBookmarked ? 'Bookmarked' : 'Save',
                            style: TextStyle(
                              color: isBookmarked ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isBookmarked 
                                  ? AppColors.accent.withValues(alpha: 0.5) 
                                  : (isDark ? Colors.white12 : Colors.black12),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9333EA).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RepoDetailScreen(owner: repo.owner.login, repoName: repo.name),
                                ),
                              );
                            },
                            icon: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Explore', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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

  Widget _buildMetricItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label, 
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
