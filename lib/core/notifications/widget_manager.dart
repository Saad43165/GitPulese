import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/models/repo_model.dart';
import '../../core/utils/formatters.dart';
import 'home_widgets_ui.dart';

class WidgetManager {
  static const String appGroupId = 'group.com.gitpulse.app';
  static const String androidWidgetName = 'TrendingWidgetProvider';

  static Future<void> updateTrendingWidget(GhRepo repo) async {
    try {
      await HomeWidget.saveWidgetData<String>('repo_name', repo.fullName);
      await HomeWidget.saveWidgetData<String>('repo_desc', repo.description ?? 'No description');
      await HomeWidget.saveWidgetData<String>('repo_stars', formatCount(repo.stargazersCount));
      await HomeWidget.saveWidgetData<String>('repo_lang', repo.language ?? 'Mixed');
      
      // For deep linking
      await HomeWidget.saveWidgetData<String>('repo_owner', repo.owner.login);
      await HomeWidget.saveWidgetData<String>('repo_raw_name', repo.name);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
      );
    } catch (e) {
      // Failed to update widget, safe to ignore as it's not critical
    }
  }

  static Future<void> updateProfileWidgets(dynamic user, List<GhRepo> repos) async {
    try {
      // 1. Overview Widget (Small)
      await HomeWidget.renderFlutterWidget(
        WidgetUiBuilder.buildOverview(user),
        key: 'overview_image',
        logicalSize: const Size(160, 160),
      );
      await HomeWidget.updateWidget(androidName: 'OverviewWidgetProvider');

      // 2. Top Repo Widget (Medium)
      if (repos.isNotEmpty) {
        final sortedRepos = List<GhRepo>.from(repos)..sort((a, b) => b.stargazersCount.compareTo(a.stargazersCount));
        await HomeWidget.renderFlutterWidget(
          WidgetUiBuilder.buildTopRepo(sortedRepos.first),
          key: 'toprepo_image',
          logicalSize: const Size(320, 160),
        );
      }
      await HomeWidget.updateWidget(androidName: 'TopRepoWidgetProvider');

      // 3. Contribution Widget (Large)
      int totalStars = repos.fold(0, (sum, r) => sum + r.stargazersCount);
      int totalForks = repos.fold(0, (sum, r) => sum + r.forksCount);
      await HomeWidget.renderFlutterWidget(
        WidgetUiBuilder.buildContribution(totalStars, totalForks),
        key: 'contrib_image',
        logicalSize: const Size(320, 320),
      );
      await HomeWidget.updateWidget(androidName: 'ContributionWidgetProvider');

      // 4. Language Widget (Medium)
      final langCounts = <String, int>{};
      for (final r in repos) {
        if (r.language != null) langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
      if (langCounts.isNotEmpty) {
        await HomeWidget.renderFlutterWidget(
          WidgetUiBuilder.buildLanguage(langCounts),
          key: 'lang_image',
          logicalSize: const Size(320, 160),
        );
      }
      await HomeWidget.updateWidget(androidName: 'LanguageWidgetProvider');
    } catch (e) {
      // Safe to ignore if widget doesn't exist or fails
    }
  }
}
