import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/notification_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/state_views.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../widgets/app_markdown.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/expandable_section.dart';

class TrackedReposScreen extends ConsumerStatefulWidget {
  const TrackedReposScreen({super.key});

  @override
  ConsumerState<TrackedReposScreen> createState() => _TrackedReposScreenState();
}

class _TrackedReposScreenState extends ConsumerState<TrackedReposScreen> {
  bool _checking = false;
  int _activeTab = 0; // 0: Alert Settings, 1: Changelog Feed

  Future<void> _checkNow() async {
    HapticFeedback.mediumImpact();
    setState(() => _checking = true);
    try {
      final count = await ref.refresh(manualCheckResultProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'No new releases found.'
                  : 'Found $count new release(s) — check notifications.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
      ref.invalidate(trackedReposProvider);
      ref.invalidate(trackedReleasesFeedProvider);
    }
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.accent : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.accent)
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackedAsync = ref.watch(trackedReposProvider);
    final backgroundEnabled = ref.watch(backgroundChecksEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Release Tracking'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Pill segmented navigation control
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Alert Settings', Icons.tune_rounded),
                  _buildTabButton(1, 'Changelog Feed', Icons.rss_feed_rounded),
                ],
              ),
            ),
            Expanded(
              child: _activeTab == 0
                  ? _buildSettingsTab(context, isDark, trackedAsync, backgroundEnabled)
                  : _buildFeedTab(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Map<String, dynamic>>> trackedAsync,
    bool backgroundEnabled,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: AppSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Background checks depend on your OS background runner. Tap "Check now" to fetch immediate release updates.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Periodic background checks',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Queries GitHub API every ~6 hours',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    value: backgroundEnabled,
                    activeColor: AppColors.accent,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      ref.read(backgroundCheckTogglerProvider).setEnabled(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              onPressed: _checking ? null : _checkNow,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: GlowingIndicator(size: 16),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_checking ? 'Checking…' : 'Check now for new releases'),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Tracked Repositories',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
            ),
          ),
        ),
        trackedAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'Not tracking any repos',
                    subtitle: 'Open any repository details screen and tap "Track for updates"',
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = items[i];
                    final fullName = item['fullName'] as String;
                    final lastTag = item['lastKnownReleaseTag'] as String?;
                    final lastChecked = item['lastCheckedAt'] as int?;
                    final parts = fullName.split('/');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSurface(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (parts.length == 2) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RepoDetailScreen(owner: parts[0], repoName: parts[1]),
                              ),
                            );
                          }
                        },
                        showAccentStripe: true,
                        accentColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastTag != null
                                        ? 'Latest: $lastTag${lastChecked != null ? ' · ${timeago.format(DateTime.fromMillisecondsSinceEpoch(lastChecked))}' : ''}'
                                        : 'No release history yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            );
          },
          loading: () => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: const ShimmerListCard(),
                ),
                childCount: 3,
              ),
            ),
          ),
          error: (e, _) => SliverFillRemaining(
            child: ErrorStateView(
              message: e.toString(),
              onRetry: () => ref.invalidate(trackedReposProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedTab(bool isDark) {
    final feedAsync = ref.watch(trackedReleasesFeedProvider);

    return feedAsync.when(
      data: (releases) {
        if (releases.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 48),
            child: EmptyStateView(
              icon: Icons.history_edu_rounded,
              title: 'No release logs found',
              subtitle: 'Tracked repositories do not have any releases published, or you are not tracking any repos.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trackedReleasesFeedProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            itemCount: releases.length,
            itemBuilder: (context, idx) {
              final r = releases[idx];
              final repoFullName = r['repoFullName'] as String? ?? '';
              final tagName = r['tag_name'] as String? ?? '';
              final releaseName = r['name'] as String? ?? tagName;
              final body = r['body'] as String? ?? '';
              final publishedAtStr = r['published_at'] as String? ?? '';
              final publishedAt = DateTime.tryParse(publishedAtStr);
              final htmlUrl = r['html_url'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppSurface(
                  padding: const EdgeInsets.all(16),
                  showAccentStripe: true,
                  accentColor: AppColors.accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.rocket_launch_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              repoFullName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (publishedAt != null)
                            Text(
                              timeago.format(publishedAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        releaseName.isEmpty ? tagName : releaseName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (body.trim().isNotEmpty) ...[
                        ExpandableSection(
                          collapsedHeight: 180,
                          child: AppMarkdown(
                            data: body,
                            selectable: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(htmlUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('View on GitHub', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: 'Failed to load releases: $e',
        onRetry: () => ref.invalidate(trackedReleasesFeedProvider),
      ),
    );
  }
}
