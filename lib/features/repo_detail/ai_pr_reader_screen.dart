import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/glowing_indicator.dart';
import '../../../widgets/app_markdown.dart';
import '../../../widgets/app_back_button.dart';

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
    // Only generate if we don't already have a cached result
    Future.microtask(() {
      final current = ref.read(prSummaryProvider);
      if (current == null || current is AsyncError) {
        _generate();
      }
    });
  }

  void _generate() {
    ref.read(prSummaryProvider.notifier).summarizePR(
          owner: widget.owner,
          repo: widget.repoName,
          pullNumber: widget.pullNumber,
          title: widget.title,
        );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(prSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI PR Reader',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
            ),
            Text(
              '#${widget.pullNumber} · ${widget.title}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // Regenerate action — only visible when we have a result
        actions: [
          if (summaryAsync?.valueOrNull != null)
            TextButton.icon(
              onPressed: summaryAsync is AsyncLoading ? null : _generate,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Regenerate', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: _buildBody(summaryAsync, isDark),
    );
  }

  Widget _buildBody(AsyncValue<String?>? summaryAsync, bool isDark) {
    // Null means never triggered — show trigger screen
    if (summaryAsync == null) {
      return _buildIdle(isDark);
    }

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return _buildIdle(isDark);
        }
        return _buildResult(summary, isDark);
      },
      loading: () => _buildLoading(isDark),
      error: (e, _) => _buildError(e, isDark),
    );
  }

  Widget _buildIdle(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 60),
          const SizedBox(height: 20),
          const Text(
            'Translate this PR',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Let AI explain the code changes in plain English.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate AI Summary'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GlowingIndicator(size: 60),
          const SizedBox(height: 24),
          const Text(
            'Reading Pull Request Diff…',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Translating code changes into plain English.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This usually takes 5–15 seconds.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(String summary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 20,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 26),
                const SizedBox(width: 10),
                const Text(
                  'AI Translation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                // PR number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${widget.pullNumber}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppMarkdown(data: summary, selectable: true),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e, bool isDark) {
    final errStr = e.toString();
    // User-friendly messages for known error types
    final isRateLimit = errStr.contains('rate limit') || errStr.contains('429');
    final is500 = errStr.contains('500') || errStr.contains('Internal Server');
    final isNoDiff = errStr.contains('diff is empty') || errStr.contains('no code diff');

    String headline = 'Could Not Read PR Diff';
    String detail = errStr;
    String tip = 'Tap Retry below.';

    if (isRateLimit) {
      headline = 'AI Rate Limit Hit';
      detail = 'The AI service is temporarily busy.';
      tip = 'Wait a moment, then tap Retry.';
    } else if (is500) {
      headline = 'AI Service Busy (500)';
      detail = 'The AI server returned an error — this is usually temporary.';
      tip = 'Wait 10–20 seconds and tap Retry. Very large PRs may need truncation.';
    } else if (isNoDiff) {
      headline = 'No Diff Available';
      detail = 'This PR has no code diff — it may be empty, merged, or access is restricted.';
      tip = 'Try opening the PR directly on GitHub.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              is500 || isRateLimit ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              tip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
