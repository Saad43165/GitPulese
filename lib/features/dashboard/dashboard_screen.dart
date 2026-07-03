import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/settings_providers.dart';
import '../../features/auth/auth_dialog.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/glowing_indicator.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../user_detail/user_detail_screen.dart';
import '../compare/compare_screen.dart';

class _Topic {
  const _Topic({required this.id, required this.label, required this.icon, required this.gradient});
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradient;
}

const List<_Topic> _curatedTopics = [
  _Topic(id: 'All', label: 'Trending All', icon: Icons.explore_rounded, gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
  _Topic(id: 'Python', label: 'AI & ML', icon: Icons.psychology_rounded, gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
  _Topic(id: 'JavaScript', label: 'Web & UI', icon: Icons.web_rounded, gradient: [Color(0xFFF59E0B), Color(0xFFD97706)]),
  _Topic(id: 'Dart', label: 'Mobile Dev', icon: Icons.phone_android_rounded, gradient: [Color(0xFF10B981), Color(0xFF047857)]),
  _Topic(id: 'Go', label: 'Backend', icon: Icons.dns_rounded, gradient: [Color(0xFFEC4899), Color(0xFFBE185D)]),
  _Topic(id: 'Rust', label: 'Systems', icon: Icons.settings_suggest_rounded, gradient: [Color(0xFF6B7280), Color(0xFF374151)]),
];

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
                expandedHeight: 140,
                pinned: true,
                stretch: true,
                // Collapsed bg: use standard scaffold color, no hardcoded GitHub colors
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 1,
                shadowColor: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.12),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CompareScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sports_martial_arts_rounded, color: AppColors.accent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Arena', 
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final authUser = ref.watch(authenticatedUserProvider);
                      return authUser.when(
                        data: (user) {
                          if (user == null) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: FilledButton.icon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => const AuthDialog(),
                                ),
                                icon: const Icon(Icons.login_rounded, size: 15),
                                label: const Text('Sign In'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          }
                          final firstName = (user.name ?? user.login).split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UserDetailScreen(username: user.login),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.accent, width: 1.5),
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: user.avatarUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: AppColors.accent.withValues(alpha: 0.2),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      firstName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                    final expandedH = constraints.biggest.height;
                    // 0.0 = fully expanded, 1.0 = fully collapsed
                    final t = ((expandedH - collapsedHeight) / (140 - collapsedHeight))
                        .clamp(0.0, 1.0);
                    final collapseProgress = 1.0 - t;
                    final bgOpacity = (t > 0.3 ? (t - 0.3) / 0.7 : 0.0).clamp(0.0, 1.0);
                    final titleOpacity = (collapseProgress > 0.5 ? (collapseProgress - 0.5) / 0.5 : 0.0).clamp(0.0, 1.0);

                    return Container(
                      decoration: BoxDecoration(
                        // Expanded: fully transparent to show gradient; Collapsed: solid surface
                        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(collapseProgress),
                        border: collapseProgress > 0.85
                            ? Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 0.5,
                                ),
                              )
                            : null,
                      ),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 24, bottom: 14, right: 160),
                        centerTitle: false,
                        title: Opacity(
                          opacity: titleOpacity,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.rocket_launch_rounded,
                                size: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Explore',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  fontSize: 17,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        background: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + kToolbarHeight - 10,
                            left: 24,
                            right: 24,
                            bottom: 10,
                          ),
                          child: Opacity(
                            opacity: bgOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 22,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Explore',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Trending repos & top developers',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : Colors.black.withValues(alpha: 0.5),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),


              const SliverToBoxAdapter(child: SizedBox(height: 8)),


              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _AiInsightCard(trending: trending),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Curated Topics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMiniPeriod(TrendingPeriod.daily, '1D', period, ref),
                            _buildMiniPeriod(TrendingPeriod.weekly, '1W', period, ref),
                            _buildMiniPeriod(TrendingPeriod.monthly, '1M', period, ref),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _curatedTopics.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final topic = _curatedTopics[i];
                      final selected = (language == null && topic.id == 'All') || language == topic.id;
                      return _buildTopicChip(topic, selected, ref, context);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: isDark ? Colors.white : Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Trending Repositories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: isDark ? Colors.white : Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Top Developers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      itemCount: result.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                  loading: () => const SizedBox(height: 140, child: GlowingIndicator()),
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

  Widget _buildMiniPeriod(TrendingPeriod p, String label, TrendingPeriod current, WidgetRef ref) {
    final selected = current == p;
    return GestureDetector(
      onTap: () => ref.read(trendingPeriodProvider.notifier).state = p,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip(_Topic topic, bool selected, WidgetRef ref, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        ref.read(trendingLanguageProvider.notifier).state = topic.id == 'All' ? null : topic.id;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: topic.gradient, begin: Alignment.centerLeft, end: Alignment.centerRight)
              : null,
          color: selected ? null : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12)),
            width: 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: topic.gradient.last.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              topic.icon,
              size: 15,
              color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              topic.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
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
        width: 110,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with accent ring
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@$login',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              followers > 0
                ? '${formatCount(followers)} followers'
                : '$publicRepos repos',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            // GitHub link button
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://github.com/$login'),
                mode: LaunchMode.externalApplication,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 10, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text(
                      'GitHub',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightCard extends StatefulWidget {
  const _AiInsightCard({required this.trending});
  final AsyncValue trending;

  @override
  State<_AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<_AiInsightCard> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.trending.maybeWhen(
      data: (result) {
        if (result.items.isEmpty) return const SizedBox.shrink();
        
        final Map<String, int> langs = {};
        for (var r in result.items) {
          if (r.language != null) {
            langs[r.language] = (langs[r.language] ?? 0) + 1;
          }
        }
        
        String insight = "Today's open-source landscape is highly diverse with many rising tools.";
        if (langs.isNotEmpty) {
          final sorted = langs.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
          final top = sorted.first.key;
          final pct = (sorted.first.value / result.items.length * 100).toInt();
          insight = "The current trending landscape is heavily leaning towards $top, making up $pct% of today's top growing repositories.";
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('AI Daily Insight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                        GestureDetector(
                          onTap: () => setState(() => _isVisible = false),
                          child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
