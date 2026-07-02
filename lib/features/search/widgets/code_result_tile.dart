import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_and_search_models.dart';
import '../../../widgets/app_surface.dart';

class CodeResultTile extends StatelessWidget {
  const CodeResultTile({super.key, required this.result});
  final GhCodeResult result;

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ],
      ),
    );
  }
}