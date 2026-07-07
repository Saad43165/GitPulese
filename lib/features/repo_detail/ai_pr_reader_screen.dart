import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/glowing_indicator.dart';
import '../../../widgets/app_markdown.dart';

class AiPrReaderScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;
  final int pullNumber;
  final String title;

  const AiPrReaderScreen({
    super.key,
    required this.owner,
    required this.repoName,
    required this.pullNumber,
    required this.title,
  });

  @override
  ConsumerState<AiPrReaderScreen> createState() => _AiPrReaderScreenState();
}

class _AiPrReaderScreenState extends ConsumerState<AiPrReaderScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(prSummaryProvider.notifier).summarizePR(
      owner: widget.owner,
      repo: widget.repoName,
      pullNumber: widget.pullNumber,
      title: widget.title,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(prSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI PR Reader', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent)),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: summaryAsync.when(
        data: (summary) {
          if (summary == null) {
            return const Center(child: Text('Could not generate summary.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    blurRadius: 20,
                  )
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'AI Translation',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppMarkdown(
                    data: summary,
                    selectable: true,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GlowingIndicator(size: 60),
              const SizedBox(height: 24),
              Text(
                'Reading Pull Request Diff...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Translating code changes into plain English.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Failed to read PR diff',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    ref.read(prSummaryProvider.notifier).summarizePR(
                      owner: widget.owner,
                      repo: widget.repoName,
                      pullNumber: widget.pullNumber,
                      title: widget.title,
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
