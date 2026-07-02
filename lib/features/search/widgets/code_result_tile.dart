import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_and_search_models.dart';
import '../../../providers/phase2_providers.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/glowing_indicator.dart';

class CodeResultTile extends ConsumerWidget {
  const CodeResultTile({super.key, required this.result});
  final GhCodeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return AppSurface(
      onTap: () => launchUrl(Uri.parse(result.htmlUrl), mode: LaunchMode.externalApplication),
      showAccentStripe: true,
      accentColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AdaptiveIcons.code, size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  result.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.path,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondary,
                  fontFamily: 'monospace',
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  result.repoFullName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final parts = result.repoFullName.split('/');
                  _showExplanationSheet(context, ref, parts[0], parts[1], result.path, result.name);
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Explain', style: TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  foregroundColor: AppColors.accent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExplanationSheet(BuildContext context, WidgetRef ref, String owner, String repo, String path, String filename) {
    ref.read(codeExplainerProvider.notifier).explainCode(owner: owner, repo: repo, path: path, filename: filename);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(codeExplainerProvider);
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI Explanation: $filename',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Expanded(
                      child: state.when(
                        data: (explanation) {
                          if (explanation == null) return const SizedBox.shrink();
                          return SingleChildScrollView(
                            controller: scrollController,
                            child: MarkdownBody(
                              data: explanation,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
                                code: TextStyle(backgroundColor: isDark ? Colors.black26 : Colors.black12, fontFamily: 'monospace'),
                              ),
                            ),
                          );
                        },
                        loading: () => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlowingIndicator(size: 40),
                              SizedBox(height: 16),
                              Text('Reading and analyzing code...'),
                            ],
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            e.toString(),
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}