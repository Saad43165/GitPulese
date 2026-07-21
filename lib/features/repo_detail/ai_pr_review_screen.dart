import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../data/models/user_and_search_models.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/app_markdown.dart';

class AiPrReviewScreen extends ConsumerStatefulWidget {
  const AiPrReviewScreen({super.key});

  @override
  ConsumerState<AiPrReviewScreen> createState() => _AiPrReviewScreenState();
}

class _AiPrReviewScreenState extends ConsumerState<AiPrReviewScreen> {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey _prUrlKey = GlobalKey();
  String? _selectedRepoOwner;
  String? _selectedRepoName;
  final GlobalKey _prPasteKey = GlobalKey();
  final GlobalKey _prRunKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_pr_review_tutorial') ?? false;
      if (!seen && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          ShowcaseView.get().startShowCase([
            _prUrlKey,
            _prPasteKey,
            _prRunKey,
          ]);
          await prefs.setBool('seen_pr_review_tutorial', true);
        }
      }
    });
  }

  void _onUrlChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    ref.invalidate(prReviewProvider);
    super.dispose();
  }

  Future<void> _handlePaste() async {
    try {
      final data = await Clipboard.getData('text/plain');
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        setState(() {
          _urlController.text = text;
        });
        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pasted PR URL: $text'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clipboard is empty or does not contain text')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clipboard access error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _runReview() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a GitHub Pull Request URL')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ref.read(prReviewProvider.notifier).reviewPullRequest(url);
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rate_review_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('AI PR Reviewer'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is this feature?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'This screen lets you review code modifications proposed in GitHub Pull Requests. It analyzes commits for security risks, performance regressions, and clean code guidelines.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Uses GitHub Pull Request API to pull code diff streams.\n'
                '• Parses diff boundaries to isolate modified code blocks.\n'
                '• Passes segmented code fragments to Groq LLM to check security hotspots, edge-cases, and logical errors.\n'
                '• Offers Quick Commit support to push suggestions directly to the PR branch.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Paste a PR link (e.g. github.com/owner/repo/pull/1) or select an open PR from your active repository list.\n'
                '2. Click "Analyze Pull Request" to trigger code auditing.\n'
                '3. Review line comments, select a file, and click Apply Patch to automatically commit fixes back to GitHub.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(prReviewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'AI PR Reviewer',
                subtitle: 'Identify bugs, security issues, and optimization suggestions instantly.',
                trailing: IconButton(
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => _showHelpDialog(context),
                  tooltip: 'How to use this feature',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // URL Input section
                    AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Enter Pull Request URL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Showcase(
                            key: _prUrlKey,
                            title: 'Pull Request URL',
                            description: 'Paste the direct URL link to the GitHub Pull Request (e.g. "https://github.com/owner/repo/pull/1") to fetch commit changes.',
                            titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            tooltipBackgroundColor: const Color(0xFF1E293B),
                            tooltipBorderRadius: BorderRadius.circular(12),
                            blurValue: 2,
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'https://github.com/owner/repo/pull/1',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                                suffixIcon: _urlController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _urlController.clear();
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                        tooltip: 'Clear input',
                                      )
                                    : Showcase(
                                        key: _prPasteKey,
                                        title: 'Paste Clipboard URL',
                                        description: 'Instantly paste the link copied in your device clipboard directly into the URL input field.',
                                        titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                        descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                                        tooltipBackgroundColor: const Color(0xFF1E293B),
                                        tooltipBorderRadius: BorderRadius.circular(12),
                                        blurValue: 2,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: AppColors.accent,
                                          ),
                                          onPressed: _handlePaste,
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.paste_rounded, size: 14),
                                              SizedBox(width: 4),
                                              Text('Paste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Showcase(
                            key: _prRunKey,
                            title: 'Analyze Code Changes',
                            description: 'Trigger the AI engine to request the branch differences, audit changed code files, and build a review report detailing security warnings or structural fixes.',
                            titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            tooltipBackgroundColor: const Color(0xFF1E293B),
                            tooltipBorderRadius: BorderRadius.circular(12),
                            blurValue: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _runReview,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Analyze Pull Request',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Result/State section
                    reviewAsync.when(
                      data: (result) {
                        if (result == null) {
                          return _buildInitialTip(isDark);
                        }
                        return _buildReviewResult(result, isDark);
                      },
                      loading: () => _buildLoadingState(isDark),
                      error: (error, _) => _buildErrorState(error.toString(), isDark),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepositorySelector(bool isDark, GhUser? authUser) {
    final List<Map<String, dynamic>> popularRepos = [
      {'owner': 'flutter', 'name': 'flutter', 'label': 'Flutter', 'icon': Icons.flutter_dash_rounded},
      {'owner': 'facebook', 'name': 'react', 'label': 'React', 'icon': Icons.code_rounded},
      {'owner': 'dart-lang', 'name': 'sdk', 'label': 'Dart SDK', 'icon': Icons.terminal_rounded},
      {'owner': 'microsoft', 'name': 'vscode', 'label': 'VS Code', 'icon': Icons.desktop_mac_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Repository to Scan PRs',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...popularRepos.map((repo) {
                final isSelected = _selectedRepoOwner == repo['owner'] && _selectedRepoName == repo['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRepoOwner = repo['owner'];
                        _selectedRepoName = repo['name'];
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.accent.withValues(alpha: 0.15) 
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : (isDark ? Colors.white10 : Colors.black12),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(repo['icon'] as IconData, color: isSelected ? AppColors.accent : Colors.grey, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            repo['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (authUser != null)
                ...ref.watch(userReposProvider(authUser.login)).maybeWhen(
                  data: (repos) {
                    return repos.map((repo) {
                      final isSelected = _selectedRepoOwner == authUser.login && _selectedRepoName == repo.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRepoOwner = authUser.login;
                              _selectedRepoName = repo.name;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 90,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.accent.withValues(alpha: 0.15) 
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.accent : (isDark ? Colors.white10 : Colors.black12),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_pin_rounded, color: AppColors.accent, size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  repo.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList();
                  },
                  orElse: () => <Widget>[],
                ),
            ],
          ),
        ),
        if (_selectedRepoOwner != null && _selectedRepoName != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildPullRequestList(isDark, _selectedRepoOwner!, _selectedRepoName!),
        ],
      ],
    );
  }

  Widget _buildPullRequestList(bool isDark, String owner, String repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text(
                    'Open Pull Requests in',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '$owner/$repo',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                setState(() {
                  _selectedRepoOwner = null;
                  _selectedRepoName = null;
                });
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ref.watch(repoPullRequestsProvider((owner: owner, repo: repo))).when(
          data: (prs) {
            if (prs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No open pull requests found.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }
            return Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: prs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final pr = prs[index];
                  final title = pr['title'] as String? ?? 'Pull Request';
                  final number = pr['number'] as int? ?? 0;
                  final author = (pr['user'] as Map<String, dynamic>?)?['login'] as String? ?? 'unknown';

                  return ListTile(
                    dense: true,
                    title: Text(
                      '#$number $title',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('by $author', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.accent),
                    onTap: () {
                      final url = 'https://github.com/$owner/$repo/pull/$number';
                      _urlController.text = url;
                      _runReview();
                    },
                  );
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: GlowingIndicator(size: 20)),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Failed to load PRs: $err',
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialTip(bool isDark) {
    final authUser = ref.watch(authenticatedUserProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRepositorySelector(isDark, authUser),
        const SizedBox(height: AppSpacing.lg),
        AppSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tip: Select a repository to scan open pull requests, or paste any public GitHub PR link manually.',
                  style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const GlowingIndicator(size: 60),
          const SizedBox(height: 24),
          const Text(
            'Performing Code Review...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Downloading pull request diff & running AI diagnostics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDark) {
    return AppSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Review Failed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => ref.read(prReviewProvider.notifier).reset(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Dismiss'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  ref.read(prReviewProvider.notifier).reset();
                  Future.delayed(const Duration(milliseconds: 100), _runReview);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildReviewResult(PrReviewResult result, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PR metadata card
        AppSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.merge_type_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.owner}/${result.repo} #${result.pullNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Proposed by @${result.author} on branch ${result.branchName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Review markdown card
        AppSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security_update_warning_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Diagnostics Report',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppMarkdown(
                data: result.reviewMarkdown,
                selectable: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI Auto-Patching & Quick Commit section
        _PrAutoPatchSection(result: result),
      ],
    );
  }
}

class _PrAutoPatchSection extends ConsumerStatefulWidget {
  const _PrAutoPatchSection({
    required this.result,
  });

  final PrReviewResult result;

  @override
  ConsumerState<_PrAutoPatchSection> createState() => _PrAutoPatchSectionState();
}

class _PrAutoPatchSectionState extends ConsumerState<_PrAutoPatchSection> {
  String? _selectedFile;
  bool _isCommitting = false;

  Future<void> _applyPatch(String patchedContent) async {
    if (_selectedFile == null) return;
    setState(() {
      _isCommitting = true;
    });

    try {
      final github = ref.read(githubApiServiceProvider);
      
      final details = await github.getFileDetails(
        widget.result.owner,
        widget.result.repo,
        _selectedFile!,
        ref: widget.result.branchName,
      );

      final sha = details['sha'] as String;

      await github.updateFile(
        owner: widget.result.owner,
        repo: widget.result.repo,
        path: _selectedFile!,
        content: patchedContent,
        sha: sha,
        message: 'style: apply AI PR review suggestions for ${_selectedFile!.split('/').last}',
        branch: widget.result.branchName,
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patch pushed successfully to ${widget.result.branchName}! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(prPatchProvider.notifier).reset();
        setState(() {
          _selectedFile = null;
          _isCommitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to commit patch: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isCommitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(prFilesProvider((
      owner: widget.result.owner,
      repo: widget.result.repo,
      pullNumber: widget.result.pullNumber,
    )));

    final patchAsync = ref.watch(prPatchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_fix_high_rounded,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Auto-Patching & Quick Commit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select a modified file to compile AI recommendations and directly commit a patched fix to the PR branch.',
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),

          filesAsync.when(
            data: (files) {
              final modifiedFiles = files
                  .where((f) => f['status'] == 'modified' || f['status'] == 'added')
                  .map((f) => f['filename'] as String)
                  .toList();

              if (modifiedFiles.isEmpty) {
                return const Text(
                  'No patchable files found in this PR.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedFile,
                    hint: const Text('Choose a file to patch...', style: TextStyle(fontSize: 13)),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: modifiedFiles.map((file) {
                      return DropdownMenuItem<String>(
                        value: file,
                        child: Text(
                          file.split('/').last,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedFile = val;
                      });
                      ref.read(prPatchProvider.notifier).reset();
                    },
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 12),
                    if (patchAsync.valueOrNull == null && !patchAsync.isLoading)
                      FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(prPatchProvider.notifier).generatePatch(
                            owner: widget.result.owner,
                            repo: widget.result.repo,
                            path: _selectedFile!,
                            branch: widget.result.branchName,
                            prDiff: widget.result.diff,
                            reviewComments: widget.result.reviewMarkdown,
                          );
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('Generate Code Fix'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: GlowingIndicator(size: 20),
                ),
              ),
            ),
            error: (err, _) => Text(
              'Failed to retrieve files: $err',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),

          patchAsync.when(
            data: (code) {
              if (code == null) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AI Generated Patch Preview:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                      ),
                      TextButton.icon(
                        onPressed: () => ref.read(prPatchProvider.notifier).reset(),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Retry', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCommitting ? null : () => ref.read(prPatchProvider.notifier).reset(),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isCommitting ? null : () => _applyPatch(code),
                          icon: _isCommitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: GlowingIndicator(size: 16),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: Text(_isCommitting ? 'Committing...' : 'Commit & Push'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Column(
              children: [
                SizedBox(height: 20),
                GlowingIndicator(size: 40),
                SizedBox(height: 12),
                Text(
                  'Synthesizing refactoring code fix...',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ],
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Compilation failed: $err',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
