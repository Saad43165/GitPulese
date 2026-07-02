import 'package:gitexplorer/core/network/dio_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/history_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/phase2_providers.dart';
import '../../providers/repo_detail_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/detail_section.dart';
import '../../widgets/state_views.dart';
import '../compare/compare_screen.dart';
import '../triage/triage_screen.dart';
import '../user_detail/user_detail_screen.dart';
import 'widgets/ai_summary_card.dart';
import 'widgets/risk_checker_card.dart';
import 'widgets/security_advisories_card.dart';
import 'widgets/similar_repos_section.dart';
import 'widgets/star_history_chart.dart';
import '../../widgets/expandable_section.dart';

class RepoDetailScreen extends ConsumerStatefulWidget {
  const RepoDetailScreen({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  ConsumerState<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends ConsumerState<RepoDetailScreen> {
  bool _loggedView = false;

  @override
  Widget build(BuildContext context) {
    final args = (owner: widget.owner, repo: widget.repoName);
    final repoAsync = ref.watch(repoDetailProvider(args));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: AppDecorations.pageGradient(context),
          child: repoAsync.when(
        data: (repo) {
          if (!_loggedView) {
            _loggedView = true;
            Future.microtask(() => ref.read(historyActionsProvider).logViewed(
                  type: 'viewed_repo',
                  name: repo.fullName,
                  subtitle: repo.description,
                  avatarUrl: repo.owner.avatarUrl,
                ));
          }
          final bookmarkedAsync = ref.watch(isBookmarkedProvider(repo.id));

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 64,
                title: Text(repo.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    icon: Badge(
                      isLabelVisible: ref.watch(compareListProvider).isNotEmpty,
                      label: Text('${ref.watch(compareListProvider).length}'),
                      child: const Icon(Icons.compare_arrows),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CompareScreen()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(AdaptiveIcons.share),
                    onPressed: () => Share.share(repo.htmlUrl),
                  ),
                  bookmarkedAsync.when(
                    data: (saved) => IconButton(
                      icon: Icon(saved ? AdaptiveIcons.star : AdaptiveIcons.starOutline,
                          color: saved ? AppColors.star : null),
                      onPressed: () => ref.read(bookmarkActionsProvider).toggle(repo),
                    ),
                    loading: () => const SizedBox(width: 48),
                    error: (_, __) => const SizedBox(width: 48),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSurface(
                        showAccentStripe: true,
                        accentColor: AppColors.colorForLanguage(repo.language),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'repo-avatar-${repo.id}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    child: CachedNetworkImage(
                                      imageUrl: repo.owner.avatarUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => UserDetailScreen(username: repo.owner.login),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          repo.name,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                              ),
                                        ),
                                        Text(
                                          repo.owner.login,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (repo.description != null && repo.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                repo.description!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ],
                            if (repo.topics.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: repo.topics
                                    .map((t) => Chip(
                                          label: Text(t),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _StatsRow(repo: repo),
                      const SizedBox(height: AppSpacing.lg),
                      _HealthCard(repo: repo),
                      const SizedBox(height: AppSpacing.lg),
                      AiSummaryCard(repo: repo),
                      const SizedBox(height: AppSpacing.lg),
                      _ActionButtons(repo: repo, owner: widget.owner, repoName: widget.repoName),
                      DetailSection(
                        title: 'Star History',
                        subtitle: 'Growth over the last 12 months',
                        icon: Icons.show_chart_rounded,
                        wrapInSurface: true,
                        child: StarHistoryChart(repo: repo),
                      ),
                      DetailSection(
                        title: 'Alternatives',
                        subtitle: 'Similar repos by language and topics',
                        icon: Icons.hub_outlined,
                        wrapInSurface: false,
                        child: SimilarReposSection(repo: repo),
                      ),
                      DetailSection(
                        title: 'Dependency & License Risk',
                        icon: Icons.policy_outlined,
                        child: RiskCheckerCard(repo: repo),
                      ),
                      DetailSection(
                        title: 'Security Advisories',
                        icon: Icons.shield_outlined,
                        child: SecurityAdvisoriesCard(repo: repo),
                      ),
                      DetailSection(
                        title: 'Languages',
                        icon: Icons.code_rounded,
                        wrapInSurface: false,
                        child: _LanguagesSection(owner: widget.owner, repoName: widget.repoName),
                      ),
                      DetailSection(
                        title: 'Contributors',
                        icon: Icons.groups_outlined,
                        wrapInSurface: false,
                        child: _ContributorsSection(owner: widget.owner, repoName: widget.repoName),
                      ),
                      DetailSection(
                        title: 'Latest Releases',
                        icon: Icons.new_releases_outlined,
                        wrapInSurface: false,
                        child: _ReleasesSection(owner: widget.owner, repoName: widget.repoName),
                      ),
                      DetailSection(
                        title: 'README',
                        icon: Icons.article_outlined,
                        child: _ReadmeSection(owner: widget.owner, repoName: widget.repoName),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: GlowingIndicator()),
        error: (e, _) => ErrorStateView(
          message: e is GitHubApiException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(repoDetailProvider(args)),
        ),
        ),
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.repo, required this.owner, required this.repoName});

  final dynamic repo;
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCompare = ref.watch(compareListProvider).any((r) => r.id == repo.id);
    final compareFull = ref.watch(compareListProvider).length >= 3;
    final trackedAsync = ref.watch(isTrackedProvider(repo.id));

    Widget actionButton(String label, IconData icon, VoidCallback? onTap, {bool isActive = false}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accent : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          actionButton(
            'GitHub', 
            Icons.open_in_new_rounded, 
            () => launchUrl(Uri.parse(repo.htmlUrl), mode: LaunchMode.externalApplication),
          ),
          if (repo.homepage != null && repo.homepage!.isNotEmpty) ...[
            const SizedBox(width: 12),
            actionButton(
              'Website', 
              Icons.language_rounded, 
              () => launchUrl(Uri.parse(repo.homepage!), mode: LaunchMode.externalApplication),
            ),
          ],
          const SizedBox(width: 12),
          actionButton(
            inCompare ? 'Remove' : 'Compare', 
            inCompare ? Icons.remove_circle_outline : Icons.compare_arrows_rounded, 
            inCompare 
              ? () => ref.read(compareListProvider.notifier).remove(repo.id)
              : (compareFull ? null : () => ref.read(compareListProvider.notifier).add(repo)),
            isActive: inCompare,
          ),
          const SizedBox(width: 12),
          actionButton(
            'Triage', 
            Icons.checklist_rtl_rounded, 
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TriageScreen(owner: owner, repoName: repoName))),
          ),
          const SizedBox(width: 12),
          trackedAsync.when(
            data: (tracked) => actionButton(
              tracked ? 'Tracking' : 'Track', 
              tracked ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, 
              () => ref.read(trackingActionsProvider).toggle(repo),
              isActive: tracked,
            ),
            loading: () => const Expanded(child: Center(child: GlowingIndicator())),
            error: (_, __) => const Expanded(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.repo});
  final dynamic repo;

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String value, String label, [Color? color]) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 18, color: color ?? Theme.of(context).iconTheme.color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          stat(AdaptiveIcons.star, formatCount(repo.stargazersCount), 'Stars', AppColors.star),
          stat(AdaptiveIcons.fork, formatCount(repo.forksCount), 'Forks'),
          stat(Icons.visibility_outlined, formatCount(repo.watchersCount), 'Watching'),
          stat(Icons.error_outline_rounded, formatCount(repo.openIssuesCount), 'Issues'),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.repo});
  final dynamic repo;

  Color _color(int score) {
    if (score >= 75) return AppColors.success;
    if (score >= 55) return AppColors.accent;
    if (score >= 35) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final score = repo.healthScore as int;
    final label = repo.healthLabel as String;
    final color = _color(score);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: score / 100, color: color, backgroundColor: color.withValues(alpha: 0.15), strokeWidth: 5),
                Text('$score', style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Repo Health: $label', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(
                  'Last pushed ${timeago.format(repo.pushedAt)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagesSection extends ConsumerWidget {
  const _LanguagesSection({required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langsAsync = ref.watch(repoLanguagesProvider((owner: owner, repo: repoName)));

    return langsAsync.when(
      data: (langs) {
        if (langs.isEmpty) return const SizedBox.shrink();
        final total = langs.values.fold<int>(0, (a, b) => a + b);
        final entries = langs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: entries.map((e) {
                  final pct = e.value / total;
                  return Expanded(
                    flex: (pct * 1000).round().clamp(1, 1000),
                    child: Container(height: 8, color: AppColors.colorForLanguage(e.key)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: entries.take(6).map((e) {
                final pct = (e.value / total * 100).toStringAsFixed(1);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.colorForLanguage(e.key))),
                    const SizedBox(width: 5),
                    Text('${e.key} $pct%', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: GlowingIndicator(size: 24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ContributorsSection extends ConsumerWidget {
  const _ContributorsSection({required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributorsAsync = ref.watch(repoContributorsProvider((owner: owner, repo: repoName)));

    return contributorsAsync.when(
      data: (contributors) {
        if (contributors.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: contributors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = contributors[i] as dynamic;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(username: c.login))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: CachedNetworkImage(imageUrl: c.avatarUrl, width: 44, height: 44, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: GlowingIndicator(size: 24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  const _ReleasesSection({required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(repoReleasesProvider((owner: owner, repo: repoName)));

    return releasesAsync.when(
      data: (releases) {
        if (releases.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...releases.take(3).map((r) {
              final tag = r['tag_name'] as String? ?? '';
              final name = r['name'] as String? ?? tag;
              final publishedAt = DateTime.tryParse(r['published_at'] as String? ?? '');
              final url = r['html_url'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppSurface(
                  onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.label_outline_rounded, size: 20, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (publishedAt != null)
                              Text(
                                timeago.format(publishedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: GlowingIndicator(size: 24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReadmeSection extends ConsumerWidget {
  const _ReadmeSection({required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readmeAsync = ref.watch(repoReadmeProvider((owner: owner, repo: repoName)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return readmeAsync.when(
      data: (readme) {
        if (readme == null || readme.trim().isEmpty) {
          return Text('No README available.', style: TextStyle(color: Theme.of(context).hintColor));
        }
        return AppSurface(
          padding: const EdgeInsets.all(20),
          child: ExpandableSection(
            collapsedHeight: 300,
            child: MarkdownBody(
              data: readme,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 24),
                h2: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
                p: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.6),
                code: TextStyle(backgroundColor: isDark ? Colors.black26 : Colors.black12, fontFamily: 'monospace'),
                codeblockDecoration: BoxDecoration(color: isDark ? Colors.black45 : Colors.black12, borderRadius: BorderRadius.circular(12)),
              ),
              onTapLink: (text, href, title) {
                if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              },
            ),
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: GlowingIndicator())),
      error: (e, _) => Text('Could not load README.', style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }
}
