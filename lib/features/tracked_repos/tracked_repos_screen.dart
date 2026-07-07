import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/notification_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import '../repo_detail/repo_detail_screen.dart';

class TrackedReposScreen extends ConsumerStatefulWidget {
  const TrackedReposScreen({super.key});

  @override
  ConsumerState<TrackedReposScreen> createState() => _TrackedReposScreenState();
}

class _TrackedReposScreenState extends ConsumerState<TrackedReposScreen> {
  bool _checking = false;

  Future<void> _checkNow() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackedAsync = ref.watch(trackedReposProvider);
    final backgroundEnabled = ref.watch(backgroundChecksEnabledProvider);

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Tracked Repos')),
        body: SafeArea(
          top: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              showBackButton: false,
              title: 'Release Tracking',
              subtitle: 'Get notified when tracked repos ship new releases',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: AppSurface(
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
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accent),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Background checks depend on your OS and aren\'t guaranteed on a schedule. Use "Check now" for immediate results.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Periodic background checks'),
                      subtitle: const Text('Every ~6 hours when supported'),
                      value: backgroundEnabled,
                      onChanged: (v) => ref.read(backgroundCheckTogglerProvider).setEnabled(v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.md,
                AppSpacing.pageHorizontal,
                AppSpacing.md,
              ),
              child: FilledButton.icon(
                onPressed: _checking ? null : _checkNow,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_checking ? 'Checking…' : 'Check now for new releases'),
              ),
            ),
            Expanded(
              child: trackedAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.notifications_none_rounded,
                      title: 'Not tracking any repos',
                      subtitle: 'Open a repo and tap "Track for updates"',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      0,
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final fullName = item['fullName'] as String;
                      final lastTag = item['lastKnownReleaseTag'] as String?;
                      final lastChecked = item['lastCheckedAt'] as int?;
                      final parts = fullName.split('/');

                      return AppSurface(
                        onTap: () {
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
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lastTag != null
                                        ? 'Latest: $lastTag${lastChecked != null ? ' · ${timeago.format(DateTime.fromMillisecondsSinceEpoch(lastChecked))}' : ''}'
                                        : 'No release history yet',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const ShimmerList(),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(trackedReposProvider),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
