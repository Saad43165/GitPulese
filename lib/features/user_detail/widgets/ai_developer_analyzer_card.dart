import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_and_search_models.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/remote/groq_api_service.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/glowing_indicator.dart';

class AiDeveloperAnalyzerCard extends ConsumerWidget {
  const AiDeveloperAnalyzerCard({super.key, required this.user, required this.repos});
  final GhUser user;
  final List<GhRepo> repos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyzerState = ref.watch(developerAnalyzerProvider(user.login));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurface(
      showAccentStripe: true,
      accentColor: AppColors.accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'AI Developer Vibe Check',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          analyzerState.when(
            data: (analysis) {
              if (analysis == null) {
                return Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(developerAnalyzerProvider(user.login).notifier).analyzeDeveloper(
                        username: user.login,
                        bio: user.bio,
                        topRepos: repos,
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Analyze Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  analysis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 60,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlowingIndicator(size: 20),
                    SizedBox(height: 8),
                    Text('Analyzing repositories and bio...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(height: 8),
                  Text(
                    e is GroqApiException ? e.message : 'Analysis failed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.read(developerAnalyzerProvider(user.login).notifier).analyzeDeveloper(
                      username: user.login,
                      bio: user.bio,
                      topRepos: repos,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
