import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/remote/github_api_service.dart';
import '../../../providers/search_providers.dart';

const _languages = [
  'Dart', 'Python', 'JavaScript', 'TypeScript', 'Java', 'Kotlin',
  'Swift', 'Go', 'Rust', 'C++', 'C', 'C#', 'PHP', 'Ruby', 'HTML', 'CSS',
];
const _licenses = ['mit', 'apache-2.0', 'gpl-3.0', 'bsd-3-clause', 'mpl-2.0', 'unlicense'];

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    final notifier = ref.read(searchFiltersProvider.notifier);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.lg,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxxl,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search Filters',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filters.activeCount} active',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => notifier.state = const SearchFilters(),
                        child: const Text('Reset all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _FilterGroup(
                    title: 'Sort by',
                    child: _ChipRow(
                      RepoSort.values.map((s) {
                        final label = switch (s) {
                          RepoSort.bestMatch => 'Best match',
                          RepoSort.stars => 'Most stars',
                          RepoSort.forks => 'Most forks',
                          RepoSort.updated => 'Recently updated',
                        };
                        return _FilterChip(
                          label: label,
                          selected: filters.sort == s,
                          onSelected: () => notifier.state = filters.copyWith(sort: s),
                        );
                      }).toList(),
                    ),
                  ),
                  _FilterGroup(
                    title: 'Created within',
                    child: _ChipRow(
                      SearchPeriod.values.map((p) {
                        final label = switch (p) {
                          SearchPeriod.allTime => 'All time',
                          SearchPeriod.today => 'Today',
                          SearchPeriod.thisWeek => 'This week',
                          SearchPeriod.thisMonth => 'This month',
                          SearchPeriod.thisYear => 'This year',
                        };
                        return _FilterChip(
                          label: label,
                          selected: filters.period == p,
                          onSelected: () => notifier.state = filters.copyWith(period: p),
                        );
                      }).toList(),
                    ),
                  ),
                  _FilterGroup(
                    title: 'Language',
                    child: _ChipRow(
                      _languages.map((lang) {
                        final selected = filters.language == lang;
                        return _FilterChip(
                          label: lang,
                          selected: selected,
                          dotColor: AppColors.colorForLanguage(lang),
                          onSelected: () => notifier.state = selected
                              ? filters.copyWith(clearLanguage: true)
                              : filters.copyWith(language: lang),
                        );
                      }).toList(),
                    ),
                  ),
                  _FilterGroup(
                    title: 'Minimum stars',
                    child: _ChipRow(
                      [10, 100, 1000, 10000, 100000].map((stars) {
                        final selected = filters.minStars == stars;
                        return _FilterChip(
                          label: '$stars+',
                          selected: selected,
                          onSelected: () => notifier.state = selected
                              ? filters.copyWith(clearMinStars: true)
                              : filters.copyWith(minStars: stars),
                        );
                      }).toList(),
                    ),
                  ),
                  _FilterGroup(
                    title: 'License',
                    child: _ChipRow(
                      _licenses.map((lic) {
                        final selected = filters.license == lic;
                        return _FilterChip(
                          label: lic.toUpperCase(),
                          selected: selected,
                          onSelected: () => notifier.state = selected
                              ? filters.copyWith(clearLicense: true)
                              : filters.copyWith(license: lic),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ),
          ],
        ),
        );
      },
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(this.chips);
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: chips);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
