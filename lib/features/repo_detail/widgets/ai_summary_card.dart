import 'package:flutter/material.dart';
import '../../../widgets/glowing_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glowing_indicator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/repo_model.dart';
import '../../../providers/phase2_providers.dart';
import '../../../providers/repo_detail_providers.dart';
import '../../../widgets/app_surface.dart';

class AiSummaryCard extends ConsumerWidget {
  const AiSummaryCard({super.key, required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(repoSummaryProvider(repo.id));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      child: _buildContent(context, ref, summaryState),
    );
  }

  Future<void> _summarize(WidgetRef ref) async {
    final readmeAsync = ref.read(
      repoReadmeProvider((owner: repo.owner.login, repo: repo.name)),
    );
    await ref.read(repoSummaryProvider(repo.id).notifier).summarize(repo, readmeAsync.value);
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AsyncValue<String>? summaryState) {
    if (summaryState == null) {
      return SizedBox(
        key: const ValueKey('idle'),
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _summarize(ref),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Generate AI summary'),
        ),
      );
    }

    return summaryState.when(
      data: (text) => AppSurface(
        key: const ValueKey('data'),
        showAccentStripe: true,
        accentColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI Summary',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Regenerate',
                  onPressed: () => _summarize(ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
      loading: () => AppSurface(
        key: const ValueKey('loading'),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: GlowingIndicator(size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Generating summary…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      error: (e, _) => AppSurface(
        key: const ValueKey('error'),
        showAccentStripe: true,
        accentColor: AppColors.danger,
        child: Row(
          children: [
            Expanded(
              child: Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(repoSummaryProvider(repo.id).notifier).reset(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
