import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/settings_providers.dart';
import '../auth/auth_dialog.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final trending = ref.watch(trendingReposProvider);
    final topUsers = ref.watch(topUsersProvider);
    final authUser = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trendingReposProvider);
            ref.invalidate(topUsersProvider);
          },
          child: AnimationLimiter(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
              // 1. Clean Modern AppBar / Header Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Drawer Trigger & Brand Name
                      Row(
                        children: [
                          Builder(
                            builder: (innerContext) => GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                innerContext.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: const Icon(Icons.menu_open_rounded, color: AppColors.accent, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GitPulse',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'v1.0.1 Live',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Header Action Shortcuts: Notifications, Arena & Profile
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Notifications Shortcut Icon
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(AppRoutes.notifications);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                              child: const Icon(Icons.notifications_outlined, color: AppColors.accent, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Arena Shortcut
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(AppRoutes.compare);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 15),
                                  SizedBox(width: 4),
                                  Text(
                                    'Arena',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Profile / Sign In
                          authUser.when(
                            data: (user) {
                              if (user == null) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    showDialog(context: context, builder: (_) => const AuthDialog());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/github.png',
                                          height: 14,
                                          width: 14,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return GestureDetector(
                                onTap: () => context.push(AppRoutes.userPath(user.login)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.accent, width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 13,
                                    backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                  ),
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Rate Limit Warning Banner for Unauthenticated Mode
              if (ref.watch(githubPatProvider) == null || ref.watch(githubPatProvider)!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Guest Mode: 60 API requests/hr limit.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showDialog(context: context, builder: (_) => const AuthDialog());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Connect PAT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Top Developers Section (Featured First)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.military_tech_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Top Developers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 92,
                  child: topUsers.when(
                    data: (result) {
                      if (result.items.isEmpty) return const SizedBox.shrink();
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: result.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, i) {
                          final user = result.items[i];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(AppRoutes.userPath(user.login));
                            },
                            child: SizedBox(
                              width: 68,
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                                        ),
                                        child: CircleAvatar(
                                          radius: 26,
                                          backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isDark ? AppColors.darkBg : Colors.white, width: 1.5),
                                          ),
                                          child: Text(
                                            '#${i + 1}',
                                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    user.login,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: GlowingIndicator(size: 24)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // 3. Compact Essential Tools Pill Row (Single Horizontal Line, ~44px height)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildQuickToolChip(
                        context: context,
                        isDark: isDark,
                        icon: Icons.code_rounded,
                        label: 'AI Editor',
                        color: const Color(0xFFEC4899),
                        onTap: () => context.push(AppRoutes.editor),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickToolChip(
                        context: context,
                        isDark: isDark,
                        icon: Icons.rate_review_rounded,
                        label: 'PR Review',
                        color: const Color(0xFF6366F1),
                        onTap: () => context.push(AppRoutes.prReview),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickToolChip(
                        context: context,
                        isDark: isDark,
                        icon: Icons.rocket_launch_rounded,
                        label: 'DevOps',
                        color: const Color(0xFFEF4444),
                        onTap: () => context.push(AppRoutes.devops),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickToolChip(
                        context: context,
                        isDark: isDark,
                        icon: Icons.offline_pin_rounded,
                        label: 'Offline Vault',
                        color: const Color(0xFF10B981),
                        onTap: () => context.push(AppRoutes.vault),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 4. Trending Repositories Grid (Main Highlight)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Trending Repositories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Top 10 Today',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              
              trending.when(
                data: (result) {
                  if (result.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final repo = result.items[i];
                          return AnimationConfiguration.staggeredGrid(
                            position: i,
                            columnCount: 2,
                            duration: const Duration(milliseconds: 375),
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: _buildGridRepoCard(repo, context, isDark),
                              ),
                            ),
                          );
                        },
                        childCount: result.items.length > 10 ? 10 : result.items.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: GlowingIndicator(size: 32)),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(child: ErrorStateView(message: 'Error loading repos', onRetry: () => ref.invalidate(trendingReposProvider))),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToolChip({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridRepoCard(dynamic repo, BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.repoPath(repo.owner.login, repo.name)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
          image: DecorationImage(
            image: CachedNetworkImageProvider(repo.owner.avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFDE047), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      formatCount(repo.stargazersCount),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                repo.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.languageColors[repo.language] ?? Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      repo.language ?? 'Unknown',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
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
}
