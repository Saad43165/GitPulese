import 'package:gitexplorer/core/network/dio_client.dart' show GitHubApiException;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/repo_model.dart';
import '../../data/models/user_and_search_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/detail_section.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../widgets/app_back_button.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../auth/auth_dialog.dart';
import 'developer_wrapped_screen.dart';
import 'widgets/ai_developer_analyzer_card.dart';
import '../../core/notifications/widget_manager.dart';
import '../../widgets/github_analytics_section.dart';

final _userDetailProvider = userDetailProvider;

final _userReposProvider = userReposProvider;

final _userFollowersProvider =
    FutureProvider.autoDispose.family((ref, String username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserFollowers(username);
});

final _userFollowingProvider =
    FutureProvider.autoDispose.family((ref, String username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserFollowing(username);
});

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.username});
  final String username;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _logged = false;
  final GlobalKey _devCardKey = GlobalKey();
  final GlobalKey _aiAnalyzerKey = GlobalKey();
  final GlobalKey _analyticsSectionKey = GlobalKey();

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_user_detail_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _devCardKey,
          _aiAnalyzerKey,
          _analyticsSectionKey,
        ]);
        await prefs.setBool('seen_user_detail_tutorial', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(_userDetailProvider(widget.username));
    final reposAsync = ref.watch(_userReposProvider(widget.username));
    final authUser = ref.watch(authenticatedUserProvider);
    final isOwnProfile = authUser.valueOrNull?.login.toLowerCase() == widget.username.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Update Android Home Screen Widgets whenever we successfully load profile data
    ref.listen(_userDetailProvider(widget.username), (prev, nextUser) {
      if (nextUser is AsyncData) {
        final repos = ref.read(_userReposProvider(widget.username)).valueOrNull;
        if (repos != null) {
          WidgetManager.updateProfileWidgets(nextUser.value, repos);
        }
      }
    });
    ref.listen(_userReposProvider(widget.username), (prev, nextRepos) {
      if (nextRepos is AsyncData) {
        final user = ref.read(_userDetailProvider(widget.username)).valueOrNull;
        if (user != null) {
          WidgetManager.updateProfileWidgets(user, nextRepos.value as List<GhRepo>);
        }
      }
    });

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: userAsync.when(
          data: (user) {
            if (!_logged) {
              _logged = true;
              Future.microtask(() {
                ref.read(historyActionsProvider).logViewed(
                      type: 'viewed_user',
                      name: user.login,
                      subtitle: user.bio,
                      avatarUrl: user.avatarUrl,
                    );
                _checkAndShowTutorial();
              });
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_userDetailProvider(widget.username));
                ref.invalidate(_userReposProvider(widget.username));
                ref.invalidate(_userFollowersProvider(widget.username));
                ref.invalidate(_userFollowingProvider(widget.username));
              },
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(user, isDark),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),

                        // Info chips - location, joined, website
                        if (user.company != null || user.location != null ||
                            user.createdAt != null ||
                            (user.blog != null && user.blog!.isNotEmpty) ||
                            (user.twitterUsername != null && user.twitterUsername!.isNotEmpty))
                          _buildInfoChips(user),

                        const SizedBox(height: AppSpacing.lg),

                        // Action Buttons — own profile vs other user
                        _buildActionButtons(user, isOwnProfile: isOwnProfile),
                        const SizedBox(height: AppSpacing.xl),

                        // Stats Box
                        _buildStatsBox(user, isOwnProfile: isOwnProfile),
                        const SizedBox(height: AppSpacing.xl),

                        // Contribution Graph
                        _buildContributionGraph(context, reposAsync.value),

                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
                
                // Content based on Repositories
                reposAsync.maybeWhen(
                  data: (repos) {
                    if (repos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Developer Card Generator Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                            child: Showcase(
                              key: _devCardKey,
                              title: 'Developer Card Generator',
                              description: 'Generate a personalized developer summary card compiling your top languages and star accomplishments. Perfect for sharing on Twitter/LinkedIn.',
                              titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                              tooltipBackgroundColor: const Color(0xFF1E293B),
                              tooltipBorderRadius: BorderRadius.circular(12),
                              blurValue: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => Navigator.of(context).push(CardPageRoute(child: DeveloperWrappedScreen(user: user, repos: repos))),
                                    child: const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.auto_awesome_rounded, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('Generate Developer Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          
                          // AI Analyzer
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                            child: Showcase(
                              key: _aiAnalyzerKey,
                              title: 'AI Developer Agent Analyzer',
                              description: 'Trigger a deep AI review analyzing the repositories, commits, and languages of the developer. Evaluates strengths, coding styles, and offers recommendations.',
                              titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                              tooltipBackgroundColor: const Color(0xFF1E293B),
                              tooltipBorderRadius: BorderRadius.circular(12),
                              blurValue: 2,
                              child: AiDeveloperAnalyzerCard(user: user, repos: repos),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // GitPulse Analytics
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                            child: Showcase(
                              key: _analyticsSectionKey,
                              title: 'GitHub Analytics Metrics',
                              description: 'Visualize repository growth, star history tracking, active programming languages, and contribution trends.',
                              titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                              tooltipBackgroundColor: const Color(0xFF1E293B),
                              tooltipBorderRadius: BorderRadius.circular(12),
                              blurValue: 2,
                              child: GitHubAnalyticsSection(repos: repos),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Top Languages
                          _buildTopLanguages(repos, context),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                // Repositories List
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    height: 50.0,
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Repositories',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                reposAsync.when(
                  data: (repos) {
                    final compactCards = ref.watch(compactCardsProvider);
                    return SliverPadding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.pageHorizontal,
                        right: AppSpacing.pageHorizontal,
                        bottom: AppSpacing.xxl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final repo = repos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: RepoCard(
                                repo: repo,
                                compact: compactCards,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => RepoDetailScreen(owner: repo.owner.login, repoName: repo.name))),
                              ),
                            );
                          },
                          childCount: repos.length,
                        ),
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        children: List.generate(4, (_) => const ShimmerListCard()),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(child: Text('Could not load repos: $e')),
                ),
              ],
            ),
            );
          },
          loading: () => const ShimmerUserDetailPage(),
          error: (e, _) => ErrorStateView(
            message: e is GitHubApiException ? e.message : e.toString(),
            onRetry: () => ref.invalidate(_userDetailProvider(widget.username)),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(GhUser user, bool isDark) {
    return SliverAppBar(
      leading: const AppBackButton(),
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final compareList = ref.watch(accountCompareListProvider);
            final isInCompare = compareList.any((u) => u.id == user.id);
            return IconButton(
              icon: Icon(
                isInCompare ? Icons.sports_martial_arts_rounded : Icons.sports_martial_arts_outlined,
                color: isInCompare ? AppColors.accent : (isDark ? Colors.white : Colors.black),
              ),
              tooltip: isInCompare ? 'Remove from Compare Arena' : 'Add to Compare Arena',
              onPressed: () {
                if (isInCompare) {
                  HapticFeedback.lightImpact();
                  ref.read(accountCompareListProvider.notifier).remove(user.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from Compare Arena')),
                  );
                } else {
                  if (compareList.length >= 2) {
                    HapticFeedback.vibrate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Arena is full! Remove an account first.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  HapticFeedback.heavyImpact();
                  ref.read(accountCompareListProvider.notifier).add(user);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to Compare Arena!')),
                  );
                }
              },
            );
          },
        ),
        IconButton(
          icon: Icon(AdaptiveIcons.share),
          onPressed: () => Share.share('https://github.com/${widget.username}'),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
          final isCollapsed = top <= collapsedHeight + 30; // Trigger slightly before fully collapsed

          return FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 60, bottom: 14), // Leave space for back button
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 1.5),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user.avatarUrl,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.name ?? user.login,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            background: Stack(
          fit: StackFit.expand,
          children: [
            // Watermark Logo
            Positioned(
              left: -30,
              top: -30,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.03,
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 250,
                  height: 250,
                ),
              ),
            ),
            // Avatar and Name Group
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0D1117) : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: GestureDetector(
                          onTap: () => _showAvatarDialog(context, user.avatarUrl),
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      user.name ?? user.login,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.login}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      },
      ),
    );
  }

  Widget _buildActionButtons(GhUser user, {bool isOwnProfile = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isOwnProfile) ...[
          // ── Own profile ── View on GitHub + Share
          FilledButton.tonalIcon(
            onPressed: () => launchUrl(Uri.parse(user.htmlUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('View on GitHub'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => Share.share(
              'Check out my GitHub: https://github.com/${user.login}',
            ),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ] else ...[
          // ── Other user profile ── Follow
          Consumer(
            builder: (context, ref, _) {
              final pat = ref.watch(githubPatProvider);
              final isLoggedIn = pat != null && pat.isNotEmpty;
              final followState = ref.watch(userFollowProvider(user.login));
              return followState.when(
                data: (isFollowing) => FilledButton.icon(
                  onPressed: () async {
                    if (!isLoggedIn) {
                      showDialog(context: context, builder: (_) => const AuthDialog());
                      return;
                    }
                    try {
                      await ref.read(userFollowProvider(user.login).notifier).toggleFollow();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e is GitHubApiException ? e.message : e.toString()),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    !isLoggedIn
                        ? Icons.lock_outline_rounded
                        : (isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded),
                    size: 18,
                  ),
                  label: Text(!isLoggedIn ? 'Follow (Login)' : (isFollowing ? 'Unfollow' : 'Follow')),
                  style: FilledButton.styleFrom(
                    backgroundColor: !isLoggedIn
                        ? Colors.grey.shade700
                        : (isFollowing ? AppColors.danger : Theme.of(context).colorScheme.primary),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: !isLoggedIn ? 0 : 4,
                    shadowColor: !isLoggedIn
                        ? Colors.transparent
                        : (isFollowing ? AppColors.danger : Theme.of(context).colorScheme.primary).withValues(alpha: 0.4),
                  ),
                ),
                loading: () => const Center(child: GlowingIndicator(size: 24)),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: () => launchUrl(Uri.parse(user.htmlUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('GitHub'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsBox(GhUser user, {required bool isOwnProfile}) {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(userFollowProvider(user.login)); // watch for rebuild when follow state changes

        // Follower count: +1/-1 based on confirmed server state vs current optimistic state
        final notifier = ref.read(userFollowProvider(user.login).notifier);
        final followersDelta = notifier.followersDelta;

        // Clamp so counts never go below 0
        final displayFollowers =
            (user.followers + followersDelta).clamp(0, double.maxFinite).toInt();
        final displayFollowing = user.following;

        return AppSurface(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showUsersList(
                      context, ref, 'Followers', _userFollowersProvider, user.login),
                  behavior: HitTestBehavior.opaque,
                  child: _StatLabel(
                      value: formatCount(displayFollowers),
                      label: 'Followers',
                      icon: Icons.people_alt_rounded),
                ),
              ),
              Container(
                  width: 1,
                  height: 48,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showUsersList(
                      context, ref, 'Following', _userFollowingProvider, user.login),
                  behavior: HitTestBehavior.opaque,
                  child: _StatLabel(
                      value: formatCount(displayFollowing),
                      label: 'Following',
                      icon: Icons.person_add_alt_1_rounded),
                ),
              ),
              Container(
                  width: 1,
                  height: 48,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              Expanded(
                child: _StatLabel(
                    value: formatCount(user.publicRepos),
                    label: 'Repositories',
                    icon: Icons.folder_open_rounded),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildInfoChips(GhUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build list of info rows to show
    final items = <_InfoRow>[];

    if (user.company != null && user.company!.isNotEmpty) {
      items.add(_InfoRow(icon: Icons.apartment_rounded, text: user.company!));
    }
    if (user.location != null && user.location!.isNotEmpty) {
      items.add(_InfoRow(icon: Icons.location_on_rounded, text: user.location!));
    }
    if (user.twitterUsername != null && user.twitterUsername!.isNotEmpty) {
      items.add(_InfoRow(
        icon: Icons.alternate_email_rounded,
        text: '@${user.twitterUsername}',
        color: Colors.blueAccent,
        onTap: () => launchUrl(
          Uri.parse('https://twitter.com/${user.twitterUsername}'),
          mode: LaunchMode.externalApplication,
        ),
      ));
    }
    if (user.blog != null && user.blog!.isNotEmpty) {
      var url = user.blog as String;
      final displayUrl = url.replaceAll(RegExp(r'https?://'), '');
      if (!url.startsWith('http')) url = 'https://$url';
      items.add(_InfoRow(
        icon: Icons.link_rounded,
        text: displayUrl,
        color: AppColors.accent,
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
    }
    final createdAt = user.createdAt;
    if (createdAt != null) {
      items.add(_InfoRow(
        icon: Icons.calendar_today_rounded,
        text: 'Joined ${DateFormat('MMM yyyy').format(createdAt)}',
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    // Render as two-column grid of compact rows inside a surface card
    return AppSurface(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              if (i > 0) Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 15,
                        color: item.color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.color ?? Theme.of(context).colorScheme.onSurface,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.onTap != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTopLanguages(List<GhRepo> repos, BuildContext context) {
    if (repos.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<MapEntry<String, int>>>(
      future: compute(_computeTopLanguages, repos),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
        }

        final sorted = snapshot.data!;
        if (sorted.isEmpty) return const SizedBox.shrink();
        
        final total = sorted.fold<int>(0, (a, b) => a + b.value);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: DetailSection(
            title: 'Top Languages',
            subtitle: 'Based on public repositories',
            icon: Icons.pie_chart_outline_rounded,
            wrapInSurface: true,
            child: Column(
              children: sorted.take(6).map((e) {
                final pct = e.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('${e.value} repos', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          color: AppColors.colorForLanguage(e.key),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContributionGraph(BuildContext context, dynamic repos) {
    if (repos == null) return const SizedBox.shrink();

    return FutureBuilder<Map<int, int>>(
      future: compute(_computeContributionGraph, repos as List<GhRepo>),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
        }
        
        final daysActivity = snapshot.data!;
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dimText = Theme.of(context).colorScheme.onSurfaceVariant;
        const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const double gap = 3.0;
        const int rows = 7;
        const int cols = 15; // 15 weeks

        Color cellColor(int dayIndex) {
          final count = daysActivity[dayIndex] ?? 0;
          if (count == 0) return isDark ? const Color(0xFF21262D) : const Color(0xFFEBEDF0);
          if (count == 1) return const Color(0xFF9BE9A8);
          if (count == 2) return const Color(0xFF40C463);
          if (count >= 3) return const Color(0xFF216E39);
          return const Color(0xFF30A14E);
        }

    return DetailSection(
      title: 'Contributions',
      subtitle: 'Past 15 weeks',
      icon: Icons.timeline_rounded,
      wrapInSurface: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const double labelW = 26.0;
              const double labelGap = 4.0;
              final gridW = constraints.maxWidth - labelW - labelGap;
              final cellSize = (gridW - gap * (cols - 1)) / cols;
              final totalH = cellSize * rows + gap * (rows - 1);

              return SizedBox(
                height: totalH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day labels
                    SizedBox(
                      width: labelW,
                      child: Column(
                        children: List.generate(rows, (i) {
                          final showLabel = i % 2 == 0; // Mon, Wed, Fri, Sun
                          return SizedBox(
                            height: cellSize + (i < rows - 1 ? gap : 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: showLabel
                                  ? Text(
                                      dayLabels[i],
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: dimText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: labelGap),
                    // Heat grid
                    Expanded(
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: rows,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          childAspectRatio: 1,
                        ),
                        itemCount: rows * cols,
                        itemBuilder: (context, index) {
                          // index 0 = oldest (top-left), fill left-to-right col by col
                          final dayIndex = (rows * cols - 1) - index;
                          final count = daysActivity[dayIndex] ?? 0;
                          return Tooltip(
                            message: count > 0 ? '$count push${count == 1 ? '' : 'es'}' : 'No activity',
                            child: Container(
                              decoration: BoxDecoration(
                                color: cellColor(dayIndex),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${daysActivity.values.fold<int>(0, (a, b) => a + b)} pushes  ·  15 weeks',
                style: TextStyle(color: dimText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Text('Less ', style: TextStyle(color: dimText, fontSize: 10)),
                  _HeatBox(isDark ? const Color(0xFF21262D) : const Color(0xFFEBEDF0)),
                  const _HeatBox(Color(0xFF9BE9A8)),
                  const _HeatBox(Color(0xFF40C463)),
                  const _HeatBox(Color(0xFF30A14E)),
                  const _HeatBox(Color(0xFF216E39)),
                  Text(' More', style: TextStyle(color: dimText, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
      },
    );
  }

  void _showAvatarDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _showUsersList(
    BuildContext context,
    WidgetRef ref,
    String title,
    AutoDisposeFutureProviderFamily<List<GhUser>, String> providerFamily,
    String targetUsername,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Refresh list',
                      onPressed: () {
                        ref.invalidate(providerFamily(targetUsername));
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, innerRef, _) {
                    // Watch the correct provider
                    final asyncData = innerRef.watch(providerFamily(targetUsername));

                    return asyncData.when(
                      data: (users) {
                        if (users.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white24 : Colors.black26),
                                const SizedBox(height: 12),
                                Text(
                                  title == 'Following'
                                      ? 'Not following anyone yet.'
                                      : 'No followers yet.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: controller,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final followState =
                                innerRef.watch(userFollowProvider(user.login));

                            return ListTile(
                              leading: CircleAvatar(
                                  backgroundImage:
                                      CachedNetworkImageProvider(user.avatarUrl)),
                              title: Text(user.login,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              trailing: SizedBox(
                                width: 90,
                                height: 36,
                                child: followState.when(
                                  data: (isFollowing) => FilledButton(
                                    onPressed: () async {
                                      try {
                                        await innerRef
                                            .read(userFollowProvider(user.login)
                                                .notifier)
                                            .toggleFollow();
                                        // Refresh the list after follow/unfollow
                                        innerRef.invalidate(providerFamily(targetUsername));
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(e is GitHubApiException
                                                  ? e.message
                                                  : e.toString()),
                                              backgroundColor: AppColors.danger,
                                              duration:
                                                  const Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: isFollowing
                                          ? Colors.transparent
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      foregroundColor: isFollowing
                                          ? Theme.of(context).hintColor
                                          : Colors.white,
                                      side: isFollowing
                                          ? BorderSide(
                                              color: Theme.of(context)
                                                  .dividerColor)
                                          : null,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(90, 36),
                                      maximumSize: const Size(90, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      isFollowing ? 'Unfollow' : 'Follow',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  loading: () => const Center(
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => UserDetailScreen(
                                          username: user.login))),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: GlowingIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 40),
                            const SizedBox(height: 12),
                            Text('Error loading $title',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  innerRef.invalidate(providerFamily(targetUsername)),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
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
    );
  }
}

class _HeatBox extends StatelessWidget {
  const _HeatBox(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}


/// Data class for each row in the profile info card.
class _InfoRow {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onTap;
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final bool isDark;

  _StickyHeaderDelegate({required this.child, required this.height, required this.isDark});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height || isDark != oldDelegate.isDark;
  }
}

List<MapEntry<String, int>> _computeTopLanguages(List<GhRepo> repos) {
  final langCounts = <String, int>{};
  for (final r in repos) {
    if (r.language != null) {
      langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
    }
  }
  return langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

Map<int, int> _computeContributionGraph(List<GhRepo> repos) {
  final Map<int, int> daysActivity = {};
  final now = DateTime.now();
  for (final repo in repos) {
    if (repo.pushedAt != null) {
      final diff = now.difference(repo.pushedAt!).inDays;
      if (diff >= 0 && diff < 105) {
        daysActivity[diff] = (daysActivity[diff] ?? 0) + 1;
      }
    }
  }
  return daysActivity;
}
