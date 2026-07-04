import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../providers/zip_download_provider.dart';
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
  bool _showTelemetry = true;

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

  Color _badgeColor(String type) {
    if (type.startsWith('search_')) {
      return const Color(0xFF9333EA); // Purple for searches
    }
    if (type == 'viewed_repo') {
      return AppColors.accent; // Blue for repos
    }
    return AppColors.success; // Green for profiles
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    title: 'History Log',
                    subtitle: 'Your developer journey and activity trace',
                  ),
                  Expanded(
                    child: EmptyStateView(
                      icon: Icons.timeline_rounded,
                      title: 'Trace logs empty',
                      subtitle: 'Repositories, code, and profiles you interact with will map here',
                    ),
                  ),
                ],
              );
            }

            final grouped = <String, List<HistoryEntry>>{};
            for (final e in filtered) {
              grouped.putIfAbsent(_sectionFor(e.timestamp), () => []).add(e);
            }

            // Calculate telemetry metrics
            final totalCount = entries.length;
            final searchCount = entries.where((e) => e.isSearch).length;
            final viewedCount = entries.where((e) => !e.isSearch).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'History Log',
                  subtitle: filtered.isEmpty
                      ? 'No matching logs found'
                      : '${filtered.length} active logs traced',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_showTelemetry ? Icons.analytics_rounded : Icons.analytics_outlined),
                        color: _showTelemetry ? AppColors.accent : null,
                        tooltip: 'Toggle Metrics Dashboard',
                        onPressed: () => setState(() => _showTelemetry = !_showTelemetry),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        color: AppColors.danger,
                        tooltip: 'Clear history log',
                        onPressed: () => _confirmClearAll(context, ref),
                      ),
                    ],
                  ),
                ),

                // 1. Sleek Telemetry stats banner
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showTelemetry
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.pageHorizontal, 
                            right: AppSpacing.pageHorizontal, 
                            bottom: AppSpacing.md
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161B22) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildStatPill('Total Events', totalCount.toString(), Icons.timeline_rounded, AppColors.accent, isDark),
                                const SizedBox(width: 8),
                                _buildStatPill('Searches', searchCount.toString(), Icons.search_rounded, const Color(0xFF9333EA), isDark),
                                const SizedBox(width: 8),
                                _buildStatPill('Visited', viewedCount.toString(), Icons.explore_rounded, AppColors.success, isDark),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // 2. Compact Glass Search + Pill Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Filter logs...',
                          prefixIcon: const Icon(Icons.filter_list_rounded, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Row of Filter Pills
                      Row(
                        children: [
                          _buildFilterPill('All Logs', _HistoryFilter.all),
                          const SizedBox(width: 6),
                          _buildFilterPill('Searches Only', _HistoryFilter.searches),
                          const SizedBox(width: 6),
                          _buildFilterPill('Viewed Items', _HistoryFilter.viewed),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Interactive Trace Timeline
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.filter_list_off_rounded,
                          title: 'No matching logs',
                          subtitle: 'Try adjusting your filters or search keywords',
                        )
                      : AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageHorizontal,
                              0,
                              AppSpacing.pageHorizontal,
                              AppSpacing.lg,
                            ),
                            itemCount: grouped.entries.length,
                            itemBuilder: (context, sectionIndex) {
                              final section = grouped.entries.elementAt(sectionIndex);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Section Header
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          section.key.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1.5,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Timeline List of Entries
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: section.value.length,
                                    itemBuilder: (context, index) {
                                      final entry = section.value[index];
                                      final isLast = index == section.value.length - 1;
                                      final nodeColor = _badgeColor(entry.type);
                                      final nodeIcon = _iconFor(entry.type);

                                      return AnimationConfiguration.staggeredList(
                                        position: index,
                                        duration: const Duration(milliseconds: 375),
                                        child: SlideAnimation(
                                          verticalOffset: 30.0,
                                          child: FadeInAnimation(
                                            child: Dismissible(
                                              key: ValueKey(entry.id),
                                              direction: DismissDirection.endToStart,
                                              background: Container(
                                                alignment: Alignment.centerRight,
                                                padding: const EdgeInsets.only(right: AppSpacing.xl),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Colors.orange, AppColors.danger],
                                                  ),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                                              ),
                                              onDismissed: (_) => _deleteWithUndo(context, ref, entry),
                                              child: IntrinsicHeight(
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    // Timeline Vertical Trace Line
                                                    Container(
                                                      width: 32,
                                                      margin: const EdgeInsets.only(right: 8),
                                                      child: Stack(
                                                        alignment: Alignment.topCenter,
                                                        children: [
                                                          // Vertical Connector Line
                                                          if (!isLast)
                                                            Positioned(
                                                              top: 24,
                                                              bottom: 0,
                                                              width: 1.8,
                                                              child: Container(
                                                                color: isDark ? Colors.white12 : Colors.black12,
                                                              ),
                                                            ),
                                                          // Glowing indicator node
                                                          Positioned(
                                                            top: 14,
                                                            child: Container(
                                                              width: 26,
                                                              height: 26,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: isDark ? const Color(0xFF0F141C) : Colors.white,
                                                                border: Border.all(color: nodeColor, width: 2),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: nodeColor.withValues(alpha: 0.35),
                                                                    blurRadius: 8,
                                                                  )
                                                                ],
                                                              ),
                                                              child: Icon(nodeIcon, size: 12, color: nodeColor),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Glass Card Content
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                                        child: AppSurface(
                                                          onTap: () => _handleTap(context, ref, entry),
                                                          padding: const EdgeInsets.all(AppSpacing.md),
                                                          child: Row(
                                                            children: [
                                                              _HistoryAvatar(entry: entry, fallbackIcon: nodeIcon),
                                                              const SizedBox(width: AppSpacing.md),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        _TypeBadge(
                                                                          label: _labelFor(entry.type),
                                                                          color: nodeColor,
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                        Expanded(
                                                                          child: Text(
                                                                            entry.query,
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 13.5,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                                                                      const SizedBox(height: 4),
                                                                      Text(
                                                                        entry.subtitle!,
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: TextStyle(
                                                                          fontSize: 11,
                                                                          color: isDark ? Colors.white60 : Colors.black54,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      timeago.format(entry.timestamp),
                                                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(width: AppSpacing.sm),
                                                              
                                                              // Quick Actions based on type
                                                              _buildCardQuickAction(context, ref, entry, isDark),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Column(
            children: [
              PageHeader(title: 'History Log', subtitle: 'Loading trace details...'),
              Expanded(child: ShimmerList()),
            ],
          ),
          error: (e, _) => Column(
            children: [
              const PageHeader(title: 'History Log'),
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

  // Mini metric capsule builder
  Widget _buildStatPill(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // Pill filter tab builder
  Widget _buildFilterPill(String label, _HistoryFilter value) {
    final isSelected = _filter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _filter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppColors.accent.withValues(alpha: 0.5) 
                : (isDark ? Colors.white12 : Colors.black12),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // Quick Action Buttons inside cards
  Widget _buildCardQuickAction(BuildContext context, WidgetRef ref, HistoryEntry entry, bool isDark) {
    if (entry.type == 'viewed_repo') {
      return IconButton(
        icon: const Icon(Icons.download_rounded, size: 18),
        color: AppColors.accent,
        tooltip: 'Quick ZIP Download',
        onPressed: () {
          HapticFeedback.mediumImpact();
          final parts = entry.query.split('/');
          if (parts.length == 2) {
            ref.read(zipDownloadProvider.notifier).startDownload(
              owner: parts[0],
              repoName: parts[1],
              branch: 'main',
            );
          }
        },
      );
    } else if (entry.isSearch) {
      return IconButton(
        icon: const Icon(Icons.search_rounded, size: 18),
        color: const Color(0xFF9333EA),
        tooltip: 'Re-run search query',
        onPressed: () => _handleTap(context, ref, entry),
      );
    }
    return const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey);
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
        title: const Text('Clear all trace logs?'),
        content: const Text('This action will permanently wipe your local activity history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(historyActionsProvider).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear Log'),
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
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _iconBox(context),
        ),
      );
    }
    return _iconBox(context);
  }

  Widget _iconBox(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(fallbackIcon, size: 18, color: Theme.of(context).colorScheme.primary),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
