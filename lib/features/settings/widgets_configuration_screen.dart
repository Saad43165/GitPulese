import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/repo_model.dart';
import '../../core/notifications/home_widgets_ui.dart';

class WidgetsConfigurationScreen extends StatelessWidget {
  const WidgetsConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafePage(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: const Text('Home Screen Widgets'),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enhance your device\'s home screen with live GitHub statistics. Tap "Install Guide" below to learn how to add them to your device.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('How to add widgets:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.android_rounded, color: Colors.green, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Android: Long press home screen > Widgets > Search "GitPulse"', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.apple_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text('iOS: Long press home screen > Tap + icon top left > Search "GitPulse"', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(title: 'Overview Widget (Small)', subtitle: 'Quick glance at your daily GitHub stats.'),
                    const _WidgetPreview1(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(title: 'Top Repository (Medium)', subtitle: 'Track health and stars of your top repo.'),
                    const _WidgetPreview2(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(title: 'Contribution Graph (Small)', subtitle: 'Your 30-day commit heat map.'),
                    const _WidgetPreview3(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(title: 'Language Profile (Medium)', subtitle: 'Distribution of your top coding languages.'),
                    const _WidgetPreview4(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreview1 extends StatelessWidget {
  const _WidgetPreview1();
  @override
  Widget build(BuildContext context) {
    return WidgetUiBuilder.buildOverview(
      // Dynamic stub for user
      (login: 'octocat', followers: 12450, following: 42, publicRepos: 18, publicGists: 5)
    );
  }
}

class _WidgetPreview2 extends StatelessWidget {
  const _WidgetPreview2();
  @override
  Widget build(BuildContext context) {
    return WidgetUiBuilder.buildTopRepo(
      GhRepo(
        id: 1, 
        name: 'flutter', 
        fullName: 'flutter/flutter', 
        owner: GhOwner(id: 1, login: 'flutter', avatarUrl: 'https://avatars.githubusercontent.com/u/14101776?v=4', htmlUrl: '', type: 'User'),
        htmlUrl: 'https://github.com/flutter/flutter', 
        description: 'Flutter makes it easy and fast to build beautiful apps for mobile and beyond.', 
        stargazersCount: 154000, 
        forksCount: 25000, 
        watchersCount: 154000,
        openIssuesCount: 5000,
        subscribersCount: 3000,
        size: 150000,
        defaultBranch: 'master',
        fork: false,
        archived: false,
        disabled: false,
        topics: ['flutter', 'dart', 'ui'],
        language: 'Dart', 
        createdAt: DateTime.now().subtract(const Duration(days: 1000)),
        updatedAt: DateTime.now(),
        pushedAt: DateTime.now(),
      )
    );
  }
}

class _WidgetPreview3 extends StatelessWidget {
  const _WidgetPreview3();
  @override
  Widget build(BuildContext context) {
    return WidgetUiBuilder.buildContribution(154000, 25000);
  }
}

class _WidgetPreview4 extends StatelessWidget {
  const _WidgetPreview4();
  @override
  Widget build(BuildContext context) {
    return WidgetUiBuilder.buildLanguage({
      'Dart': 75,
      'C++': 15,
      'Objective-C': 10,
    });
  }
}
