import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/repo_model.dart';
import '../../providers/phase2_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(compareListProvider);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Compare'),
          actions: [
            if (repos.isNotEmpty)
              TextButton(
                onPressed: () => ref.read(compareListProvider.notifier).clear(),
                child: const Text('Clear all'),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: repos.isEmpty
            ? const Column(
                children: [
                  PageHeader(
                    title: 'Compare Repositories',
                    subtitle: 'Side-by-side metrics for up to 3 repos',
                  ),
                  Expanded(
                    child: EmptyStateView(
                      icon: Icons.compare_arrows_rounded,
                      title: 'No repos to compare',
                      subtitle: 'Open a repo and tap "Add to compare"',
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  0,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxl,
                ),
                children: [
                  PageHeader(
                    title: 'Compare Repositories',
                    subtitle: '${repos.length} ${repos.length == 1 ? 'repo' : 'repos'} selected',
                  ),
                  AppSurface(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(110),
                          1: FixedColumnWidth(150),
                          2: FixedColumnWidth(150),
                          3: FixedColumnWidth(150),
                        },
                        border: TableBorder.symmetric(
                          inside: BorderSide(color: theme.dividerColor),
                        ),
                        children: [
                          _headerRow(context, repos, ref),
                          _row(theme, 'Stars', repos.map((r) => formatCount(r.stargazersCount)).toList()),
                          _row(theme, 'Forks', repos.map((r) => formatCount(r.forksCount)).toList()),
                          _row(theme, 'Open issues', repos.map((r) => formatCount(r.openIssuesCount)).toList()),
                          _row(theme, 'Watchers', repos.map((r) => formatCount(r.watchersCount)).toList()),
                          _row(theme, 'Language', repos.map((r) => r.language ?? '—').toList()),
                          _row(theme, 'License', repos.map((r) => r.license?.name ?? 'None').toList()),
                          _row(theme, 'Last push', repos.map((r) => timeago.format(r.pushedAt)).toList()),
                          _healthRow(context, repos),
                          _row(theme, 'Issue/star ratio', repos.map((r) {
                            if (r.stargazersCount == 0) return '—';
                            final pct = (r.openIssuesCount / r.stargazersCount * 100).toStringAsFixed(2);
                            return '$pct%';
                          }).toList()),
                          _row(theme, 'Archived', repos.map((r) => r.archived ? 'Yes' : 'No').toList()),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
      ),
    );
  }

  TableRow _headerRow(BuildContext context, List<GhRepo> repos, WidgetRef ref) {
    return TableRow(
      children: [
        const SizedBox(),
        for (final r in repos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: SizedBox(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: CachedNetworkImage(imageUrl: r.owner.avatarUrl, width: 40, height: 40),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () => ref.read(compareListProvider.notifier).remove(r.id),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.danger,
                            child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    r.name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  TableRow _row(ThemeData theme, String label, List<String> values) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final v in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: SizedBox(
              child: Text(v, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  TableRow _healthRow(BuildContext context, List<GhRepo> repos) {
    Color colorFor(int score) {
      if (score >= 75) return AppColors.success;
      if (score >= 55) return AppColors.accent;
      if (score >= 35) return AppColors.warning;
      return AppColors.danger;
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            'Health score',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final r in repos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: SizedBox(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorFor(r.healthScore).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  child: Text(
                    '${r.healthScore}',
                    style: TextStyle(
                      color: colorFor(r.healthScore),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}