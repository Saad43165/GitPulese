import 'package:gitexplorer/core/network/dio_client.dart' show GitHubApiException;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/detail_section.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/glowing_indicator.dart';
import '../repo_detail/repo_detail_screen.dart';
import 'developer_wrapped_screen.dart';
import 'widgets/ai_developer_analyzer_card.dart';

final _userDetailProvider =
    FutureProvider.autoDispose.family((ref, String username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserDetail(username);
});

final _userReposProvider =
    FutureProvider.autoDispose.family((ref, String username) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserRepos(username);
});

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.username});
  final String username;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _logged = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(_userDetailProvider(widget.username));
    final reposAsync = ref.watch(_userReposProvider(widget.username));
    final compactCards = ref.watch(compactCardsProvider);

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.username),
          actions: [
            IconButton(
              icon: Icon(AdaptiveIcons.share),
              onPressed: () => Share.share('https://github.com/${widget.username}'),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: userAsync.when(
        data: (user) {
          if (!_logged) {
            _logged = true;
            Future.microtask(() => ref.read(historyActionsProvider).logViewed(
                  type: 'viewed_user',
                  name: user.login,
                  subtitle: user.bio,
                  avatarUrl: user.avatarUrl,
                ));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              AppSurface(
                showAccentStripe: true,
                accentColor: Theme.of(context).colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name ?? user.login,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              Text(
                                '@${user.login}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  _StatLabel(value: formatCount(user.followers), label: 'followers'),
                                  const SizedBox(width: AppSpacing.lg),
                                  _StatLabel(value: formatCount(user.following), label: 'following'),
                                  const SizedBox(width: AppSpacing.lg),
                                  _StatLabel(value: '${user.publicRepos}', label: 'repos'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(user.bio!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    ],
                    if (user.company != null || user.location != null || (user.blog != null && user.blog!.isNotEmpty)) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (user.company != null) _InfoChip(icon: Icons.apartment_rounded, text: user.company!),
                          if (user.location != null) _InfoChip(icon: Icons.location_on_outlined, text: user.location!),
                          if (user.blog != null && user.blog!.isNotEmpty) _InfoChip(icon: Icons.link_rounded, text: user.blog!),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => launchUrl(Uri.parse(user.htmlUrl), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('View on GitHub'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final followState = ref.watch(userFollowProvider(user.login));
                              return followState.when(
                                data: (isFollowing) => FilledButton.icon(
                                  onPressed: () => ref.read(userFollowProvider(user.login).notifier).toggleFollow(),
                                  icon: Icon(isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded, size: 18),
                                  label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isFollowing ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                    foregroundColor: isFollowing ? AppColors.danger : AppColors.success,
                                    elevation: 0,
                                  ),
                                ),
                                loading: () => const Center(child: GlowingIndicator(size: 24)),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              reposAsync.maybeWhen(
                data: (repos) {
                  if (repos.isEmpty) return const SizedBox.shrink();
                  final langCounts = <String, int>{};
                  for (final r in repos) {
                    if (r.language != null) {
                      langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
                    }
                  }
                  if (langCounts.isEmpty) return const SizedBox.shrink();
                  final sorted = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  final total = langCounts.values.fold<int>(0, (a, b) => a + b);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                        child: AiDeveloperAnalyzerCard(user: user, repos: repos),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeveloperWrappedScreen(user: user, repos: repos))),
                          icon: const Icon(Icons.style_rounded, size: 18),
                          label: const Text('Generate Developer Card', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      DetailSection(
                    title: 'Top Languages',
                    subtitle: 'Based on public repositories',
                    icon: Icons.pie_chart_outline_rounded,
                    wrapInSurface: true,
                    child: Column(
                      children: sorted.take(6).map((e) {
                        final pct = e.value / total;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('${e.value} repos', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context).dividerColor,
                                  color: AppColors.colorForLanguage(e.key),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              DetailSection(
                title: 'Repositories',
                subtitle: '${user.publicRepos} public repositories',
                icon: Icons.folder_rounded,
                wrapInSurface: false,
                child: reposAsync.when(
                data: (repos) => Column(
                  children: repos
                      .map((repo) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: RepoCard(
                              repo: repo,
                              compact: compactCards,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => RepoDetailScreen(owner: repo.owner.login, repoName: repo.name))),
                            ),
                          ))
                      .toList(),
                ),
                loading: () => Padding(padding: const EdgeInsets.all(24), child: Center(child: GlowingIndicator(size: 32))),
                error: (e, _) => Text('Could not load repos: $e'),
              ),
              ),
            ],
          );
        },
        loading: () => Center(child: GlowingIndicator(size: 40)),
        error: (e, _) => ErrorStateView(
          message: e is GitHubApiException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(_userDetailProvider(widget.username)),
        ),
        ),
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
