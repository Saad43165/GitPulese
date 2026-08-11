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
import '../../providers/settings_providers.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/state_views.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

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
        return 'Repo Search';
      case 'search_code':
        return 'Code Search';
      case 'search_user':
        return 'User Search';
      case 'search_issue':
        return 'Issue Search';
      case 'viewed_repo':
        return 'Visited Repo';
      case 'viewed_user':
        return 'Visited Profile';
      default:
        return 'Activity';
    }
  }

  Color _badgeColor(String type) {
    if (type.startsWith('search_')) {
      return const Color(0xFF8B5CF6);
    }
    if (type == 'viewed_repo') {
      return AppColors.accent;
    }
    return AppColors.success;
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

  List<InlineSpan> _highlightText(String text, TextStyle baseStyle, bool isDark) {
    if (_searchQuery.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final List<InlineSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    int start = 0;
    int index = lowerText.indexOf(lowerQuery, start);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + _searchQuery.length),
        style: baseStyle.copyWith(
          backgroundColor: AppColors.accent.withValues(alpha: 0.25),
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ));
      start = index + _searchQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: SafePage(
        reserveBottomNav: true,
        child: historyAsync.when(
          data: (entries) {
            final filtered = _applyFilters(entries);

            if (entries.isEmpty) {
              return const Column(
                children: [
                  PageHeader(
                    title: 'History Log',
                    subtitle: 'Your developer journey and activity trace',
                    showBackButton: false,
                  ),
                  Expanded(
                    child: EmptyStateView(
                      icon: Icons.timeline_rounded,
                      title: 'History log is empty',
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

            final flatItems = <_FlatHistoryItem>[];
            for (final section in grouped.entries) {
              flatItems.add(_HeaderItem(section.key));
              for (int i = 0; i < section.value.length; i++) {
                flatItems.add(_EntryItem(
                  section.value[i],
                  i,
                  i == section.value.length - 1,
                ));
              }
            }
            flatItems.add(_FooterItem());

            final totalCount = entries.length;
            final searchCount = entries.where((e) => e.isSearch).length;
            final viewedCount = entries.where((e) => !e.isSearch).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'History Log',
                  subtitle: filtered.isEmpty
                      ? 'No matching activity'
                      : '${filtered.length} activities logged',
                  showBackButton: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_showTelemetry ? Icons.analytics_rounded : Icons.analytics_outlined),
                        color: _showTelemetry ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
                        tooltip: 'Toggle Telemetry Metrics',
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

                // 1. Telemetry Stats Dashboard
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
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _buildStatPill('Total Events', totalCount.toString(), Icons.timeline_rounded, AppColors.accent, isDark),
                                    const SizedBox(width: 8),
                                    _buildStatPill('Searches', searchCount.toString(), Icons.search_rounded, const Color(0xFF8B5CF6), isDark),
                                    const SizedBox(width: 8),
                                    _buildStatPill('Visited', viewedCount.toString(), Icons.explore_rounded, AppColors.success, isDark),
                                  ],
                                ),
                                if (totalCount > 0) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      height: 6,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: searchCount == 0 ? 1 : searchCount,
                                            child: Container(color: const Color(0xFF8B5CF6)),
                                          ),
                                          Expanded(
                                            flex: viewedCount == 0 ? 1 : viewedCount,
                                            child: Container(color: AppColors.success),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Searches ${(searchCount / totalCount * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Views ${(viewedCount / totalCount * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // 2. Search & Pill Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Filter history by name or query...',
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.accent),
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
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildFilterPill('All Logs', _HistoryFilter.all, isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Searches', _HistoryFilter.searches, isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Viewed Items', _HistoryFilter.viewed, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Interactive Timeline List
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.filter_list_off_rounded,
                          title: 'No matching logs',
                          subtitle: 'Try adjusting your search query or filters',
                        )
                      : AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                            itemCount: flatItems.length,
                            itemBuilder: (context, index) {
                              final item = flatItems[index];

                              if (item is _HeaderItem) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 14, bottom: 8),
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
                                        item.title.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.2,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (item is _FooterItem) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 24, bottom: 100),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            child: Icon(
                                              Icons.history_toggle_off_rounded,
                                              size: 16,
                                              color: isDark ? Colors.white30 : Colors.black38,
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'History log tracks your latest 100 developer events',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white30 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final entryItem = item as _EntryItem;
                              final entry = entryItem.entry;
                              final isLast = entryItem.isLastInSection;
                              final indexInSec = entryItem.indexInSection;
                              final nodeColor = _badgeColor(entry.type);
                              final nodeIcon = _iconFor(entry.type);

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 300),
                                child: SlideAnimation(
                                  verticalOffset: 20.0,
                                  child: FadeInAnimation(
                                    child: Dismissible(
                                      key: ValueKey(entry.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                      ),
                                      onDismissed: (_) => _deleteWithUndo(context, ref, entry),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Timeline Line & Node
                                            Container(
                                              width: 28,
                                              margin: const EdgeInsets.only(right: 8),
                                              child: Stack(
                                                alignment: Alignment.topCenter,
                                                children: [
                                                  if (!isLast || indexInSec > 0)
                                                    Positioned(
                                                      top: indexInSec == 0 ? 24 : 0,
                                                      bottom: isLast ? null : 0,
                                                      height: isLast ? 24 : null,
                                                      width: 1.5,
                                                      child: Container(
                                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                                      ),
                                                    ),
                                                  Positioned(
                                                    top: 14,
                                                    child: Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDark ? AppColors.darkBg : Colors.white,
                                                        border: Border.all(color: nodeColor, width: 2),
                                                      ),
                                                      child: Icon(nodeIcon, size: 11, color: nodeColor),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Log Card Item
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.lightImpact();
                                                    _handleTap(context, ref, entry);
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        _HistoryAvatar(entry: entry, fallbackIcon: nodeIcon),
                                                        const SizedBox(width: 12),
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
                                                                    child: Text.rich(
                                                                      TextSpan(
                                                                        children: _highlightText(
                                                                          entry.query,
                                                                          TextStyle(
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 13,
                                                                            color: textColor,
                                                                          ),
                                                                          isDark,
                                                                        ),
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                                                                const SizedBox(height: 4),
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: _highlightText(
                                                                      entry.subtitle!,
                                                                      TextStyle(
                                                                        fontSize: 11,
                                                                        color: isDark ? Colors.white60 : Colors.black54,
                                                                      ),
                                                                      isDark,
                                                                    ),
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ],
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                timeago.format(entry.timestamp),
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: isDark ? Colors.white38 : Colors.black38,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        _buildCardQuickAction(context, ref, entry, isDark),
                                                      ],
                                                    ),
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
                        ),
                ),
              ],
            );
          },
          loading: () => const Column(
            children: [
              PageHeader(title: 'History Log', subtitle: 'Loading trace details...', showBackButton: false),
              Expanded(child: ShimmerListCards()),
            ],
          ),
          error: (e, _) => Column(
            children: [
              const PageHeader(title: 'History Log', showBackButton: false),
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

  Widget _buildStatPill(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label, 
              style: TextStyle(
                fontSize: 9, 
                color: isDark ? Colors.white54 : Colors.black54, 
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, _HistoryFilter value, bool isDark) {
    final isSelected = _filter == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _filter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppColors.accent 
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildCardQuickAction(BuildContext context, WidgetRef ref, HistoryEntry entry, bool isDark) {
    if (entry.type == 'viewed_repo') {
      return IconButton(
        icon: const Icon(Icons.download_rounded, size: 18),
        color: AppColors.accent,
        tooltip: 'Download ZIP',
        onPressed: () {
          HapticFeedback.mediumImpact();
          final parts = entry.query.split('/');
          if (parts.length == 2) {
            final pat = ref.read(githubPatProvider);
            ref.read(zipDownloadProvider.notifier).startDownload(
              owner: parts[0],
              repoName: parts[1],
              token: pat,
            );
          }
        },
      );
    } else if (entry.isSearch) {
      return IconButton(
        icon: const Icon(Icons.search_rounded, size: 18),
        color: const Color(0xFF8B5CF6),
        tooltip: 'Re-run search',
        onPressed: () => _handleTap(context, ref, entry),
      );
    }
    return Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white30 : Colors.black38);
  }

  void _handleTap(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    switch (entry.type) {
      case 'viewed_repo':
        final parts = entry.query.split('/');
        if (parts.length == 2) {
          context.push(AppRoutes.repoPath(parts[0], parts[1]));
        }
        break;
      case 'viewed_user':
        context.push(AppRoutes.userPath(entry.query));
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
        ref.read(selectedNavTabProvider.notifier).state = 1;
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
        title: const Text('Clear all history logs?'),
        content: const Text('This action will permanently remove your activity trace logs.'),
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

class _HeaderItem extends _FlatHistoryItem {
  final String title;
  _HeaderItem(this.title);
}

class _EntryItem extends _FlatHistoryItem {
  final HistoryEntry entry;
  final int indexInSection;
  final bool isLastInSection;
  _EntryItem(this.entry, this.indexInSection, this.isLastInSection);
}

class _FooterItem extends _FlatHistoryItem {}

abstract class _FlatHistoryItem {}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _HistoryAvatar extends StatelessWidget {
  final HistoryEntry entry;
  final IconData fallbackIcon;

  const _HistoryAvatar({required this.entry, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: CachedNetworkImageProvider(entry.avatarUrl!),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
      ),
      child: Icon(fallbackIcon, size: 16, color: isDark ? Colors.white70 : Colors.black54),
    );
  }
}
