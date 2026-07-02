import 'package:flutter/material.dart';
import '../../../widgets/glowing_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/repo_model.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/app_surface.dart';

class SecurityAdvisoriesCard extends ConsumerWidget {
  const SecurityAdvisoriesCard({super.key, required this.repo});
  final GhRepo repo;

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return const Color(0xFFE85D3F);
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisoriesAsync = ref.watch(securityAdvisoriesProvider(repo));

    return advisoriesAsync.when(
      data: (advisories) {
        if (advisories.isEmpty) {
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'No known security advisories for this repository.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }

        return Column(
          children: advisories.take(10).map((a) {
            final severity = a['severity'] as String?;
            final summary = a['summary'] as String? ?? 'Untitled advisory';
            final ghsaId = a['ghsa_id'] as String? ?? '';
            final url = a['html_url'] as String? ?? '';
            final color = _severityColor(severity);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppSurface(
                onTap: url.isEmpty ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                showAccentStripe: true,
                accentColor: color,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: color, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${severity?.toUpperCase() ?? 'UNKNOWN'} · $ghsaId',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (url.isNotEmpty)
                      Icon(Icons.open_in_new_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: GlowingIndicator(size: 24)),
      ),
      error: (e, _) => Text(
        'Could not check advisories: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
