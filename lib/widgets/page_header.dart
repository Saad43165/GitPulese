import 'package:flutter/material.dart';
import '../core/theme/app_spacing.dart';
import 'app_back_button.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool shouldShowBack = showBackButton ?? Navigator.of(context).canPop();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md, // reduced top padding since SafeArea handles it
          AppSpacing.pageHorizontal,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shouldShowBack) ...[
              const AppBackButton(),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                       fontWeight: FontWeight.w800,
                       letterSpacing: -0.8,
                       height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
