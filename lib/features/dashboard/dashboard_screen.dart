import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/core_providers.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../user_detail/user_detail_screen.dart';
import '../auth/auth_dialog.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../widgets/state_views.dart';
import '../../widgets/app_drawer.dart';
import '../repo_detail/ai_pr_review_screen.dart';
import '../vault/offline_codebase_vault_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../tracked_repos/tracked_repos_screen.dart';
import '../settings/settings_screen.dart';
import '../editor/ai_code_editor_screen.dart';
import '../compare/compare_screen.dart';

// --- Quick Feature Hub ---
class _FeatureAction {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final WidgetBuilder destination;
  final bool requiresGroqKey;
  const _FeatureAction(this.label, this.icon, this.gradient, this.destination, {this.requiresGroqKey = false});
}

final List<_FeatureAction> _features = [
  _FeatureAction('Offline Vault', Icons.offline_pin_rounded, const [Color(0xFF10B981), Color(0xFF059669)], (_) => const OfflineCodebaseVaultScreen()),
  _FeatureAction('Saved Items', Icons.bookmark_rounded, const [Color(0xFF3B82F6), Color(0xFF1D4ED8)], (_) => const BookmarksScreen()),
  _FeatureAction('AI Code Editor', Icons.code_rounded, const [Color(0xFFEC4899), Color(0xFFDB2777)], (_) => const AiCodeEditorScreen()),
  _FeatureAction('AI PR Review', Icons.rate_review_rounded, const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], (_) => const AiPrReviewScreen()),
  _FeatureAction('Tracked Releases', Icons.radar_rounded, const [Color(0xFF14B8A6), Color(0xFF0F766E)], (_) => const TrackedReposScreen()),
  _FeatureAction('App Settings', Icons.settings_rounded, const [Color(0xFF6B7280), Color(0xFF4B5563)], (_) => const SettingsScreen()),
];

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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Header Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (innerContext) => GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            innerContext.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white : Colors.black87, size: 22),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompareScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Arena',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          authUser.when(
                            data: (user) {
                              if (user == null) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    showDialog(context: context, builder: (_) => const AuthDialog());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/github.png',
                                          height: 16,
                                          width: 16,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return GestureDetector(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(username: user.login))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        user.login,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
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

              // Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Explore',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 1. Feature Hub (Replacing Search Bar)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _features.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) {
                      final f = _features[i];
                      return _buildFeatureHubCard(f, isDark, context);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 2. Top Developers Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Top Developers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: topUsers.when(
                    data: (result) {
                      if (result.items.isEmpty) return const SizedBox.shrink();
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: result.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) {
                          final user = result.items[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(username: user.login))),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                                    ),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    user.login,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
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
                    loading: () => const Center(child: GlowingIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 3. Trending Repositories Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Trending Repositories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              trending.when(
                data: (result) {
                  if (result.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
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
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, __) => Container(
                        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(child: ErrorStateView(message: 'Error loading repos', onRetry: () => ref.invalidate(trendingReposProvider))),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroqKeyRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text('Groq API Key Required'),
          ],
        ),
        content: const Text(
          'This AI-powered feature requires a Groq API Key. You can get a free key from console.groq.com (no credit card required) and configure it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHubCard(_FeatureAction action, bool isDark, BuildContext context) {
    final hasKey = ref.watch(groqApiKeyProvider) != null && ref.watch(groqApiKeyProvider)!.isNotEmpty;
    final isBlocked = action.requiresGroqKey && !hasKey;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isBlocked) {
          _showGroqKeyRequiredDialog(context);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: action.destination));
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBlocked
                    ? (isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [Colors.grey.shade300, Colors.grey.shade400])
                    : action.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: isBlocked
                  ? Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isBlocked ? Colors.black : action.gradient.first).withValues(alpha: isBlocked ? 0.05 : 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action.icon,
                  color: isBlocked ? (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)) : Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isBlocked ? (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)) : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isBlocked)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B), // Amber
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildGridRepoCard(dynamic repo, BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RepoDetailScreen(owner: repo.owner.login, repoName: repo.name))),
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
