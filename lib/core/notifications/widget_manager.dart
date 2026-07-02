import 'package:home_widget/home_widget.dart';
import '../../data/models/repo_model.dart';
import '../../core/utils/formatters.dart';

class WidgetManager {
  static const String appGroupId = 'group.com.gitpulse.app';
  static const String androidWidgetName = 'TrendingWidgetProvider';

  static Future<void> updateTrendingWidget(GhRepo repo) async {
    try {
      await HomeWidget.saveWidgetData<String>('repo_name', repo.fullName);
      await HomeWidget.saveWidgetData<String>('repo_desc', repo.description ?? 'No description');
      await HomeWidget.saveWidgetData<String>('repo_stars', Formatters.compactNumber(repo.stargazersCount));
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
}
