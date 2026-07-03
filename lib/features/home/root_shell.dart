import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../search/search_screen.dart';
import '../history/history_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../settings/settings_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    SearchScreen(),
    BookmarksScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: AppDecorations.pageGradient(context),
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: NavigationBar(
                height: 65,
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  HapticFeedback.lightImpact();
                  setState(() => _index = i);
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(AdaptiveIcons.home, color: AppColors.accent),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.search_outlined),
                    selectedIcon: Icon(AdaptiveIcons.search, color: AppColors.accent),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bookmark_border_rounded),
                    selectedIcon: Icon(AdaptiveIcons.bookmark, color: AppColors.accent),
                    label: 'Saved',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.history_outlined),
                    selectedIcon: Icon(AdaptiveIcons.history, color: AppColors.accent),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: Icon(AdaptiveIcons.settings, color: AppColors.accent),
                    label: 'Settings',
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
