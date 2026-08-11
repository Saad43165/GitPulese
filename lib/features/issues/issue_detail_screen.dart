import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';
import '../../core/network/dio_client.dart';

final _issueDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String owner, String repo, int number})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getIssueDetail(args.owner, args.repo, args.number);
  },
);

final _issueCommentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo, int number})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getIssueComments(args.owner, args.repo, args.number);
  },
);

class IssueDetailScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;
  final int issueNumber;
  final String title;

  const IssueDetailScreen({
    super.key,
    required this.owner,
    required this.repoName,
    required this.issueNumber,
    required this.title,
  });

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _commentController = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(githubApiServiceProvider).createIssueComment(
            widget.owner,
            widget.repoName,
            widget.issueNumber,
            body,
          );
      _commentController.clear();
      final args = (owner: widget.owner, repo: widget.repoName, number: widget.issueNumber);
      ref.invalidate(_issueCommentsProvider(args));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (owner: widget.owner, repo: widget.repoName, number: widget.issueNumber);
    final issueAsync = ref.watch(_issueDetailProvider(args));
    final commentsAsync = ref.watch(_issueCommentsProvider(args));

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          '#${widget.issueNumber} · ${widget.title}',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF0D1117),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_issueDetailProvider(args));
                ref.invalidate(_issueCommentsProvider(args));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Issue detail
                  issueAsync.when(
                    data: (issue) => _IssueHeader(issue: issue),
                    loading: () => const Center(child: GlowingIndicator(size: 28)),
                    error: (e, _) => ErrorStateView(
                      message: e is GitHubApiException ? e.message : e.toString(),
                      onRetry: () => ref.invalidate(_issueDetailProvider(args)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    'Comments',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Comments
                  commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No comments yet.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        );
                      }
                      return Column(
                        children: comments
                            .map((c) => _CommentCard(comment: c))
                            .toList(),
                      );
                    },
                    loading: () => const Center(child: GlowingIndicator(size: 24)),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          // Comment input bar
          Container(
            color: const Color(0xFF0D1117),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _posting ? null : _postComment,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueHeader extends StatelessWidget {
  final Map<String, dynamic> issue;

  const _IssueHeader({required this.issue});

  @override
  Widget build(BuildContext context) {
    final state = issue['state'] as String? ?? 'open';
    final isOpen = state == 'open';
    final user = issue['user'] as Map<String, dynamic>?;
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final login = user?['login'] as String? ?? '';
    final createdAt = issue['created_at'] as String?;
    final body = issue['body'] as String? ?? '';
    DateTime? createdDate;
    if (createdAt != null) createdDate = DateTime.tryParse(createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOpen ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  color: isOpen ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (avatarUrl.isNotEmpty)
              CircleAvatar(radius: 12, backgroundImage: NetworkImage(avatarUrl)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                login,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (createdDate != null)
              Text(
                timeago.format(createdDate),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: MarkdownBody(
              data: body,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                code: const TextStyle(
                  color: AppColors.accent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final user = comment['user'] as Map<String, dynamic>?;
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final login = user?['login'] as String? ?? '';
    final body = comment['body'] as String? ?? '';
    final createdAt = comment['created_at'] as String?;
    DateTime? createdDate;
    if (createdAt != null) createdDate = DateTime.tryParse(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (avatarUrl.isNotEmpty)
                CircleAvatar(radius: 10, backgroundImage: NetworkImage(avatarUrl)),
              if (avatarUrl.isNotEmpty) const SizedBox(width: 6),
              Text(
                login,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (createdDate != null)
                Text(
                  timeago.format(createdDate),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            MarkdownBody(
              data: body,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
