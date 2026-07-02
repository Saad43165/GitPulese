import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/glowing_indicator.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../user_detail/user_detail_screen.dart';

const _popularLanguages = [
  'All', 'Dart', 'Python', 'JavaScript', 'TypeScript',
  'Go', 'Rust', 'Java', 'Kotlin', 'Swift', 'C++',
];

class _OrbitPainter extends CustomPainter {
  final Color color;
  _OrbitPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width, 0); // Top right
    canvas.drawCircle(center, 100, paint);
    canvas.drawCircle(center, 180, paint);
    canvas.drawCircle(center, 260, paint);
    canvas.drawCircle(center, 340, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingReposProvider);
    final topUsers = ref.watch(topUsersProvider);
    final period = ref.watch(trendingPeriodProvider);
    final language = ref.watch(trendingLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trendingReposProvider);
            ref.invalidate(topUsersProvider);
          },
          edgeOffset: 120,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white, // GitHub specific colors
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
                  title: Text(
                    'Explore',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontSize: 28,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OrbitPainter(
                            isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Trending repositories and top developers on GitHub',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildPeriodPill(TrendingPeriod.daily, 'Today', period, ref, context),
                      const SizedBox(width: 8),
                      _buildPeriodPill(TrendingPeriod.weekly, 'This Week', period, ref, context),
                      const SizedBox(width: 8),
                      _buildPeriodPill(TrendingPeriod.monthly, 'This Month', period, ref, context),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Divider(
                    color: isDark ? Colors.white12 : Colors.black12,
                    height: 1,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _popularLanguages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final lang = _popularLanguages[i];
                      final selected = (language == null && lang == 'All') || language == lang;
                      return _buildLanguageChip(lang, selected, ref, context);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: isDark ? Colors.white : Colors.black, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Trending Repositories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: trending.when(
                  data: (result) => result.items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: EmptyStateView(
                            icon: Icons.search_off_rounded,
                            title: 'No trending repos',
                            subtitle: 'Try a different language or time period',
                          ),
                        )
                      : SizedBox(
                          height: 125,
                          child: AnimationLimiter(
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              itemCount: result.items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, i) {
                                final repo = result.items[i];
                                return AnimationConfiguration.staggeredList(
                                  position: i,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    horizontalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          width: 280,
                                          child: RepoCard(
                                            repo: repo,
                                            compact: true,
                                            onTap: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => RepoDetailScreen(
                                                  owner: repo.owner.login,
                                                  repoName: repo.name,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                  loading: () => const SizedBox(height: 175, child: GlowingIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorStateView(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(trendingReposProvider),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)), // Reduced gap significantly

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: isDark ? Colors.white : Colors.black, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Top Developers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: topUsers.when(
                  data: (result) => SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: result.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        final user = result.items[i];
                        return _DeveloperCard(
                          avatarUrl: user.avatarUrl,
                          login: user.login,
                          followers: user.followers,
                          publicRepos: user.publicRepos,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserDetailScreen(username: user.login),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  loading: () => const SizedBox(height: 200, child: GlowingIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load developers', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodPill(TrendingPeriod value, String label, TrendingPeriod current, WidgetRef ref, BuildContext context) {
    final isSelected = value == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => ref.read(trendingPeriodProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip(String lang, bool selected, WidgetRef ref, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => ref.read(trendingLanguageProvider.notifier).state = lang == 'All' ? null : lang,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          lang,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.avatarUrl,
    required this.login,
    required this.followers,
    required this.publicRepos,
    required this.onTap,
  });

  final String avatarUrl;
  final String login;
  final int followers;
  final int publicRepos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: Text(
                    followers > 0 
                      ? '${formatCount(followers)} followers' 
                      : (publicRepos > 0 ? '${formatCount(publicRepos)} repos' : 'GitHub User'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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