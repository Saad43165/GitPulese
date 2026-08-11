import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';
import '../../core/network/dio_client.dart';

final _prsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo, String state})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getPullRequests(args.owner, args.repo, state: args.state);
  },
);

class PullRequestsScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;

  const PullRequestsScreen({super.key, required this.owner, required this.repoName});

  @override
  ConsumerState<PullRequestsScreen> createState() => _PullRequestsScreenState();
}

class _PullRequestsScreenState extends ConsumerState<PullRequestsScreen>
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
            const Text('Pull Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0D1117),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Closed'),
            Tab(text: 'Merged'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => context.push(AppRoutes.createPrPath(widget.owner, widget.repoName)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New PR'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PrList(owner: widget.owner, repoName: widget.repoName, state: 'open'),
          _PrList(owner: widget.owner, repoName: widget.repoName, state: 'closed'),
          _PrList(owner: widget.owner, repoName: widget.repoName, state: 'closed', mergedOnly: true),
        ],
      ),
    );
  }
}

class _PrList extends ConsumerWidget {
  final String owner;
  final String repoName;
  final String state;
  final bool mergedOnly;

  const _PrList({
    required this.owner,
    required this.repoName,
    required this.state,
    this.mergedOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (owner: owner, repo: repoName, state: state);
    final prsAsync = ref.watch(_prsProvider(args));

    return prsAsync.when(
      data: (prs) {
        final filtered = mergedOnly
            ? prs.where((pr) => pr['merged_at'] != null).toList()
            : prs;
        if (filtered.isEmpty) {
          return EmptyStateView(
            icon: Icons.call_merge_rounded,
            title: 'No ${mergedOnly ? 'merged' : state} PRs',
            subtitle: 'No ${mergedOnly ? 'merged' : state} pull requests',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_prsProvider(args)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PrCard(
              pr: filtered[i],
              owner: owner,
              repoName: repoName,
            ),
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(_prsProvider(args)),
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  final Map<String, dynamic> pr;
  final String owner;
  final String repoName;

  const _PrCard({required this.pr, required this.owner, required this.repoName});

  @override
  Widget build(BuildContext context) {
    final number = pr['number'] as int? ?? 0;
    final title = pr['title'] as String? ?? '';
    final state = pr['state'] as String? ?? 'open';
    final mergedAt = pr['merged_at'];
    final head = (pr['head'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
    final base = (pr['base'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
    final user = pr['user'] as Map<String, dynamic>?;
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final comments = pr['comments'] as int? ?? 0;
    final reviewComments = pr['review_comments'] as int? ?? 0;
    final createdAt = pr['created_at'] as String?;
    DateTime? createdDate;
    if (createdAt != null) createdDate = DateTime.tryParse(createdAt);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (mergedAt != null) {
      statusColor = Colors.purpleAccent;
      statusIcon = Icons.merge_rounded;
      statusLabel = 'Merged';
    } else if (state == 'open') {
      statusColor = Colors.green;
      statusIcon = Icons.call_merge_rounded;
      statusLabel = 'Open';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.close_rounded;
      statusLabel = 'Closed';
    }

    return GestureDetector(
      onTap: () => context.push(AppRoutes.prPath(owner, repoName, number, title)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        '#$number $statusLabel',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (avatarUrl.isNotEmpty)
                  CircleAvatar(radius: 10, backgroundImage: NetworkImage(avatarUrl)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (head.isNotEmpty && base.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$head → $base',
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (createdDate != null)
                  Text(
                    timeago.format(createdDate),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                const Spacer(),
                if ((comments + reviewComments) > 0) ...[
                  const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text(
                    '${comments + reviewComments}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
