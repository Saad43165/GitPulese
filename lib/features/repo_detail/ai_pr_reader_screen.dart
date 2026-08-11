import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/ai_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_markdown.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/diff_viewer.dart';

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

class _AiPrReaderScreenState extends ConsumerState<AiPrReaderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _diff;
  bool _diffLoading = false;
  Map<String, dynamic>? _prDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _diff == null && !_diffLoading) {
        _loadDiff();
      }
    });
    // Only generate if we don't already have a cached result
    Future.microtask(() {
      final current = ref.read(prSummaryProvider);
      if (current is AsyncError || current is AsyncLoading) {
        _generate();
      }
      _loadPrDetails();
    });
  }

  Future<void> _loadPrDetails() async {
    try {
      final details = await ref
          .read(githubApiServiceProvider)
          .getPullRequestDetails(widget.owner, widget.repoName, widget.pullNumber);
      if (mounted) setState(() => _prDetails = details);
    } catch (_) {}
  }

  Future<void> _loadDiff() async {
    setState(() => _diffLoading = true);
    try {
      final diff = await ref
          .read(githubApiServiceProvider)
          .getPullRequestDiff(widget.owner, widget.repoName, widget.pullNumber);
      if (mounted) setState(() => _diff = diff ?? '');
    } catch (_) {
      if (mounted) setState(() => _diff = '');
    } finally {
      if (mounted) setState(() => _diffLoading = false);
    }
  }

  void _generate() {
    ref.read(prSummaryProvider.notifier).summarizePR(
          owner: widget.owner,
          repo: widget.repoName,
          pullNumber: widget.pullNumber,
          title: widget.title,
        );
  }

  Future<void> _mergePr() async {
    final String? method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Merge Pull Request', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select merge method:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _MergeMethodTile(
              method: 'merge',
              label: 'Create a merge commit',
              onTap: () => Navigator.of(ctx).pop('merge'),
            ),
            _MergeMethodTile(
              method: 'squash',
              label: 'Squash and merge',
              onTap: () => Navigator.of(ctx).pop('squash'),
            ),
            _MergeMethodTile(
              method: 'rebase',
              label: 'Rebase and merge',
              onTap: () => Navigator.of(ctx).pop('rebase'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
    if (method == null || !mounted) return;
    try {
      await ref.read(githubApiServiceProvider).mergePullRequest(
            widget.owner,
            widget.repoName,
            widget.pullNumber,
            mergeMethod: method,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pull request merged successfully!')),
      );
      // Reload details
      _loadPrDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(prSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prState = _prDetails?['state'] as String?;
    final isMergeable = prState == 'open';

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
        actions: [
          if (isMergeable)
            TextButton.icon(
              onPressed: _mergePr,
              icon: const Icon(Icons.merge_rounded, size: 16),
              label: const Text('Merge', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.purpleAccent),
            ),
          if (summaryAsync.valueOrNull != null)
            TextButton.icon(
              onPressed: summaryAsync is AsyncLoading ? null : _generate,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Regenerate', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
        ],
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'AI Summary'),
            Tab(text: 'Diff'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBody(summaryAsync, isDark),
          _buildDiffTab(isDark),
        ],
      ),
    );
  }

  Widget _buildDiffTab(bool isDark) {
    if (_diffLoading) {
      return const Center(child: GlowingIndicator(size: 32));
    }
    if (_diff == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.difference_rounded, color: AppColors.accent, size: 48),
            const SizedBox(height: 16),
            const Text('View PR Diff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('See the code changes in this pull request',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadDiff,
              icon: const Icon(Icons.difference_rounded),
              label: const Text('Load Diff'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ),
      );
    }
    return DiffViewer(diff: _diff!);
  }

  Widget _buildBody(AsyncValue<String?>? summaryAsync, bool isDark) {
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

class _MergeMethodTile extends StatelessWidget {
  final String method;
  final String label;
  final VoidCallback onTap;

  const _MergeMethodTile({
    required this.method,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.merge_rounded, color: Colors.purpleAccent, size: 18),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
