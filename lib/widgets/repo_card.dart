import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/repo_model.dart';

class RepoCard extends StatefulWidget {
  const RepoCard({
    super.key,
    required this.repo,
    required this.onTap,
    this.trailing,
    this.compact = false,
  });

  final GhRepo repo;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool compact;

  @override
  State<RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends State<RepoCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = widget.repo;
    final langColor = AppColors.colorForLanguage(repo.language);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: AppColors.lightTextPrimary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: langColor),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(widget.compact ? 14 : 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Hero(
                                tag: 'repo-avatar-${repo.id}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  child: CachedNetworkImage(
                                    imageUrl: repo.owner.avatarUrl,
                                    width: widget.compact ? 36 : 40,
                                    height: widget.compact ? 36 : 40,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      repo.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      repo.owner.login,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.trailing != null) widget.trailing!,
                            ],
                          ),
                          if (!widget.compact &&
                              repo.description != null &&
                              repo.description!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              repo.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              _StatPill(
                                icon: Icons.star_rounded,
                                label: formatCount(repo.stargazersCount),
                                color: AppColors.star,
                              ),
                              if (repo.language != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                _StatPill(
                                  dotColor: langColor,
                                  label: repo.language!,
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    this.icon,
    this.dotColor,
    required this.label,
    this.color,
  });

  final IconData? icon;
  final Color? dotColor;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color ?? theme.colorScheme.onSurfaceVariant)
          else if (dotColor != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}