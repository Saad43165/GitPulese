import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/history_entry.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/search_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/state_views.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../user_detail/user_detail_screen.dart';

enum _HistoryFilter { all, searches, viewed }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _sectionFor(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(t.year, t.month, t.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    if (diff < 30) return 'This month';
    return DateFormat.yMMMM().format(t);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'search_repo':
        return Icons.folder_outlined;
      case 'search_code':
        return Icons.code_rounded;
      case 'search_user':
        return Icons.person_outline_rounded;
      case 'search_issue':
        return Icons.bug_report_outlined;
      case 'viewed_repo':
        return Icons.folder_rounded;
      case 'viewed_user':
        return Icons.person_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _labelFor(String type) {
    switch (type) {
      case 'search_repo':
        return 'Search';
      case 'search_code':
        return 'Code';
      case 'search_user':
        return 'User';
      case 'search_issue':
        return 'Issue';
      case 'viewed_repo':
        return 'Repo';
      case 'viewed_user':
        return 'Profile';
      default:
        return 'Activity';
    }
  }

  Color _badgeColor(String type, BuildContext context) {
    if (type.startsWith('search_')) {
      return Theme.of(context).colorScheme.secondary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  List<HistoryEntry> _applyFilters(List<HistoryEntry> entries) {
    var filtered = entries;
    switch (_filter) {
      case _HistoryFilter.searches:
        filtered = filtered.where((e) => e.isSearch).toList();
      case _HistoryFilter.viewed:
        filtered = filtered.where((e) => !e.isSearch).toList();
      case _HistoryFilter.all:
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.query.toLowerCase().contains(q) ||
            (e.subtitle?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafePage(
        child: historyAsync.when(
          data: (entries) {
            final filtered = _applyFilters(entries);

            if (entries.isEmpty) {
              return const Column(
                children: [
                  PageHeader(
                    title: 'History',
                    subtitle: 'Recent searches and viewed profiles',
                  ),
                  Expanded(
                    child: EmptyStateView(
                      icon: Icons.history_rounded,
                      title: 'No history yet',
                      subtitle: 'Repos, users, and searches you view will appear here',
                    ),
                  ),
                ],
              );
            }

            final grouped = <String, List<HistoryEntry>>{};
            for (final e in filtered) {
              grouped.putIfAbsent(_sectionFor(e.timestamp), () => []).add(e);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'History',
                  subtitle: filtered.isEmpty
                      ? 'No matches for your filter'
                      : '${filtered.length} ${filtered.length == 1 ? 'activity' : 'activities'}',
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: () => _confirmClearAll(context, ref),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Filter history…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: SegmentedButton<_HistoryFilter>(
                    segments: const [
                      ButtonSegment(value: _HistoryFilter.all, label: Text('All')),
                      ButtonSegment(value: _HistoryFilter.searches, label: Text('Searches')),
                      ButtonSegment(value: _HistoryFilter.viewed, label: Text('Viewed')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) => setState(() => _filter = s.first),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.filter_list_off_rounded,
                          title: 'Nothing matches',
                          subtitle: 'Try a different filter or search term',
                        )
                      : AnimationLimiter(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageHorizontal,
                              0,
                              AppSpacing.pageHorizontal,
                              AppSpacing.lg,
                            ),
                            children: grouped.entries.expand((section) {
                              return [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Text(
                                  section.key,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              ...section.value.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: AnimationConfiguration.staggeredList(
                                    position: 0,
                                    duration: const Duration(milliseconds: 375),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: Dismissible(
                                          key: ValueKey(entry.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: AppSpacing.xl),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                    ),
                                    onDismissed: (_) => _deleteWithUndo(context, ref, entry),
                                    child: AppSurface(
                                      onTap: () => _handleTap(context, ref, entry),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                        vertical: AppSpacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          _HistoryAvatar(entry: entry, fallbackIcon: _iconFor(entry.type)),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    _TypeBadge(
                                                      label: _labelFor(entry.type),
                                                      color: _badgeColor(entry.type, context),
                                                    ),
                                                    const SizedBox(width: AppSpacing.sm),
                                                    Expanded(
                                                      child: Text(
                                                        entry.query,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(fontWeight: FontWeight.w700),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (entry.subtitle != null &&
                                                    entry.subtitle!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    entry.subtitle!,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            timeago.format(entry.timestamp),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ];
                    }).toList(),
                    ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Column(
            children: [
              PageHeader(title: 'History', subtitle: 'Loading recent activity…'),
              Expanded(child: ShimmerList()),
            ],
          ),
          error: (e, _) => Column(
            children: [
              const PageHeader(title: 'History'),
              Expanded(
                child: ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(historyListProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    switch (entry.type) {
      case 'viewed_repo':
        final parts = entry.query.split('/');
        if (parts.length == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RepoDetailScreen(owner: parts[0], repoName: parts[1]),
            ),
          );
        }
        break;
      case 'viewed_user':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserDetailScreen(username: entry.query)),
        );
        break;
      default:
        ref.read(searchQueryProvider.notifier).state = entry.query;
        final tab = switch (entry.type) {
          'search_repo' => SearchTab.repositories,
          'search_code' => SearchTab.code,
          'search_user' => SearchTab.users,
          'search_issue' => SearchTab.issues,
          _ => SearchTab.repositories,
        };
        ref.read(searchTabProvider.notifier).state = tab;
        Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    ref.read(historyActionsProvider).deleteEntry(entry.id!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from history'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final db = ref.read(databaseHelperProvider);
            await db.insertHistory(entry.toMap());
            ref.invalidate(historyListProvider);
          },
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(historyActionsProvider).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _HistoryAvatar extends StatelessWidget {
  const _HistoryAvatar({required this.entry, required this.fallbackIcon});

  final HistoryEntry entry;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final url = entry.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _iconBox(context),
        ),
      );
    }
    return _iconBox(context);
  }

  Widget _iconBox(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(fallbackIcon, size: 20, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
