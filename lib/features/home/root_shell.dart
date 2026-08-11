import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
    final borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              AppColors.accent.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.1),
              AppColors.accent.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.05),
            ]
          : [
              Colors.white,
              AppColors.accent.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0.8),
              Colors.white.withValues(alpha: 0.4),
            ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );

    final navItems = [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Explore'),
      (Icons.search_outlined, Icons.search_rounded, 'Search'),
      (Icons.local_fire_department_outlined, Icons.local_fire_department_rounded, 'Discover'),
      (Icons.history_outlined, Icons.history_rounded, 'History'),
      (Icons.analytics_outlined, Icons.analytics_rounded, 'Analytics'),
    ];

    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(30.5),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (i) {
                  final item = navItems[i];
                  final isSelected = index == i;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(selectedNavTabProvider.notifier).state = i;
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: isDark ? 0.22 : 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? item.$2 : item.$1,
                            color: isSelected
                                ? AppColors.accent
                                : (isDark ? Colors.white54 : Colors.black54),
                            size: 20,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.$3,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
