import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_and_search_models.dart';
import '../../../widgets/app_surface.dart';

class IssueTile extends StatelessWidget {
  const IssueTile({super.key, required this.issue});
  final GhIssue issue;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isOpen = issue.state == 'open';
    final statusColor = isOpen ? AppColors.success : AppColors.accent;

    return AppSurface(
      onTap: () => launchUrl(Uri.parse(issue.htmlUrl), mode: LaunchMode.externalApplication),
      showAccentStripe: true,
      accentColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                issue.isPullRequest
                    ? Icons.call_merge_rounded
                    : (isOpen ? Icons.radio_button_checked : Icons.check_circle_outline),
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  issue.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${issue.repoFullName} #${issue.number}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('by ${issue.user.login}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: secondary)),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: secondary),
              const SizedBox(width: 3),
              Text('${issue.comments}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: secondary)),
              const Spacer(),
              Text(timeago.format(issue.updatedAt), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: secondary)),
            ],
          ),
          if (issue.labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: issue.labels.take(4).map((l) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    l,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
