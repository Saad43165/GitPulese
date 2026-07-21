import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../search/search_screen.dart';
import '../history/history_screen.dart';
import '../discovery/discovery_screen.dart';
import '../analytics/profile_analytics_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/aurora_background.dart';

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  static const _screens = [
    DashboardScreen(),
    SearchScreen(),
    DiscoveryScreen(),
    HistoryScreen(),
    ProfileAnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedNavTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      drawer: const AppDrawer(),
      body: AuroraBackground(
        child: IndexedStack(index: index, children: _screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: _GlassNavBar(index: index, isDark: isDark),
        ),
      ),
    );
  }
}

class _GlassNavBar extends ConsumerWidget {
  const _GlassNavBar({required this.index, required this.isDark});

  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gradient border — iOS 26 glass refraction
    final borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.07),
              AppColors.accent.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.04),
            ]
          : [
              Colors.white.withValues(alpha: 0.98),
              AppColors.accent.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.6),
              Colors.white.withValues(alpha: 0.25),
            ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );

    return Container(
      height: 67,
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.accent.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        // 1px gradient border
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1117).withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(33),
              ),
              child: NavigationBar(
                height: 65,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.accent.withValues(alpha: isDark ? 0.22 : 0.13),
                selectedIndex: index,
                onDestinationSelected: (i) {
                  HapticFeedback.lightImpact();
                  ref.read(selectedNavTabProvider.notifier).state = i;
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.accentSoft),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search_rounded, color: AppColors.accentSoft),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_fire_department_outlined),
                    selectedIcon: Icon(Icons.local_fire_department_rounded, color: AppColors.accentSoft),
                    label: 'Discover',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded, color: AppColors.accentSoft),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.analytics_outlined),
                    selectedIcon: Icon(Icons.analytics_rounded, color: AppColors.accentSoft),
                    label: 'Analytics',
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
