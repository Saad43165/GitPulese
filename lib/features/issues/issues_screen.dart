import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';
import '../../core/network/dio_client.dart';
import '../../widgets/app_back_button.dart';

final _issuesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo, String state})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getRepoIssues(args.owner, args.repo, state: args.state);
  },
);

class IssuesScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;

  const IssuesScreen({super.key, required this.owner, required this.repoName});

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.owner}/${widget.repoName}',
              style: const TextStyle(fontSize: 11, color: AppColors.accent),
            ),
            const Text('Issues & PRs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0D1117),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.accent,
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Closed'),
            Tab(text: 'PRs'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => context.push(AppRoutes.createIssuePath(widget.owner, widget.repoName)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Issue'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IssuesList(owner: widget.owner, repoName: widget.repoName, state: 'open'),
          _IssuesList(owner: widget.owner, repoName: widget.repoName, state: 'closed'),
          _PrList(owner: widget.owner, repoName: widget.repoName),
        ],
      ),
    );
  }
}

class _IssuesList extends ConsumerWidget {
  final String owner;
  final String repoName;
  final String state;

  const _IssuesList({required this.owner, required this.repoName, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (owner: owner, repo: repoName, state: state);
    final issuesAsync = ref.watch(_issuesProvider(args));

    return issuesAsync.when(
      data: (items) {
        // Filter out PRs (which have pull_request field)
        final issues = items.where((i) => i['pull_request'] == null).toList();
        if (issues.isEmpty) {
          return EmptyStateView(
            icon: Icons.bug_report_outlined,
            title: 'No $state issues',
            subtitle: 'No $state issues found for this repository',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_issuesProvider(args)),
          child: AnimationLimiter(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: issues.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _IssueCard(
                      issue: issues[i],
                      owner: owner,
                      repoName: repoName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(_issuesProvider(args)),
      ),
    );
  }
}

final _prsInIssueTabProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getPullRequests(args.owner, args.repo, state: 'open');
  },
);

class _PrList extends ConsumerWidget {
  final String owner;
  final String repoName;

  const _PrList({required this.owner, required this.repoName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (owner: owner, repo: repoName);
    final prsAsync = ref.watch(_prsInIssueTabProvider(args));

    return prsAsync.when(
      data: (prs) {
        if (prs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.call_merge_rounded,
            title: 'No open PRs',
            subtitle: 'No open pull requests for this repository',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_prsInIssueTabProvider(args)),
          child: AnimationLimiter(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: prs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _IssueCard(issue: prs[i], owner: owner, repoName: repoName, isPr: true),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(_prsInIssueTabProvider(args)),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final Map<String, dynamic> issue;
  final String owner;
  final String repoName;
  final bool isPr;

  const _IssueCard({
    required this.issue,
    required this.owner,
    required this.repoName,
    this.isPr = false,
  });

  @override
  Widget build(BuildContext context) {
    final number = issue['number'] as int? ?? 0;
    final title = issue['title'] as String? ?? '';
    final state = issue['state'] as String? ?? 'open';
    final user = issue['user'] as Map<String, dynamic>?;
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final commentsCount = issue['comments'] as int? ?? 0;
    final createdAt = issue['created_at'] as String?;
    final isOpen = state == 'open';

    DateTime? createdDate;
    if (createdAt != null) createdDate = DateTime.tryParse(createdAt);

    return GestureDetector(
      onTap: () {
        if (isPr) {
          context.push(AppRoutes.prPath(owner, repoName, number, title));
        } else {
          context.push(AppRoutes.issueDetailPath(owner, repoName, number, title));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOpen
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.red.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPr
                        ? Icons.call_merge_rounded
                        : (isOpen ? Icons.radio_button_unchecked : Icons.check_circle_outline),
                    size: 12,
                    color: isOpen ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '#$number',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (avatarUrl.isNotEmpty)
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      if (avatarUrl.isNotEmpty) const SizedBox(width: 5),
                      if (createdDate != null)
                        Text(
                          timeago.format(createdDate),
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      const Spacer(),
                      if (commentsCount > 0) ...[
                        const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.white38),
                        const SizedBox(width: 3),
                        Text(
                          '$commentsCount',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
