import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';

// ── iOS 26-inspired glass surface ─────────────────────────────────────────────
//
// Uses a thin gradient border (bright top-left → dim bottom-right) to simulate
// the light-refraction of real frosted glass. A very subtle BackdropFilter adds
// depth. Works in both dark and light themes.

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.accentColor,
    this.showAccentStripe = false,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool showAccentStripe;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stripe = accentColor ?? Theme.of(context).colorScheme.primary;

    // Glass base fill
    final baseFill = backgroundColor ??
        (isDark
            ? const Color(0xFF0D1117).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.78));

    // Gradient border — bright top-left, dim bottom-right
    final borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.06),
              AppColors.accent.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.03),
            ]
          : [
              Colors.white.withValues(alpha: 0.95),
              AppColors.accent.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.2),
            ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );

    Widget content = Container(
      margin: margin,
      // Gradient border via outer gradient container + inner fill
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.07),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        // 1px gradient border padding
        padding: const EdgeInsets.all(1),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF161B22) 
                : Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 1),
          ),
          child: showAccentStripe
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: stripe),
                      Expanded(
                        child: Padding(
                          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                  child: child,
                ),
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: content,
        ),
      );
    }

    return content;
  }
}
