import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../data/models/repo_model.dart';
import 'app_surface.dart';

class GitHubAnalyticsSection extends StatelessWidget {
  const GitHubAnalyticsSection({
    super.key,
    required this.repos,
    this.compact = false,
  });

  final List<GhRepo> repos;
  final bool compact;

  Color _getLanguageColor(String lang) {
    switch (lang.toLowerCase()) {
      case 'python': return const Color(0xFF3572A5);
      case 'javascript': return const Color(0xFFF1E05A);
      case 'typescript': return const Color(0xFF3178C6);
      case 'java': return const Color(0xFFB07219);
      case 'dart': return const Color(0xFF00B4AB);
      case 'html': return const Color(0xFFE34C26);
      case 'css': return const Color(0xFF563D7C);
      case 'go': return const Color(0xFF00ADD8);
      case 'rust': return const Color(0xFFDEA584);
      case 'swift': return const Color(0xFFF05138);
      case 'c++': return const Color(0xFFF34B7D);
      case 'ruby': return const Color(0xFF701516);
      case 'c#': return const Color(0xFF178600);
      case 'php': return const Color(0xFF4F5D95);
      case 'kotlin': return const Color(0xFFA97BFF);
      default: return const Color(0xFF64748B);
    }
  }

  List<PieChartSectionData> _buildPieSections(List<MapEntry<String, int>> sortedLangs, bool compact) {
    final total = sortedLangs.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return [];
    
    final List<PieChartSectionData> sections = [];
    int otherSum = 0;
    
    for (int i = 0; i < sortedLangs.length; i++) {
      if (i < 4) {
        final val = sortedLangs[i].value;
        final percentage = (val / total) * 100;
        sections.add(
          PieChartSectionData(
            color: _getLanguageColor(sortedLangs[i].key),
            value: val.toDouble(),
            title: compact ? '' : '${percentage.toStringAsFixed(0)}%',
            radius: compact ? 18 : 22,
            showTitle: !compact,
            titleStyle: TextStyle(
              fontSize: compact ? 8 : 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      } else {
        otherSum += sortedLangs[i].value;
      }
    }
    
    if (otherSum > 0) {
      final percentage = (otherSum / total) * 100;
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF94A3B8),
          value: otherSum.toDouble(),
          title: compact ? '' : '${percentage.toStringAsFixed(0)}%',
          radius: compact ? 18 : 22,
          showTitle: !compact,
          titleStyle: TextStyle(
            fontSize: compact ? 8 : 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  List<Widget> _buildLegends(List<MapEntry<String, int>> sortedLangs, bool compact) {
    final total = sortedLangs.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return [];
    
    final List<Widget> legends = [];
    int otherSum = 0;
    
    for (int i = 0; i < sortedLangs.length; i++) {
      if (i < 4) {
        final name = sortedLangs[i].key;
        final percentage = (sortedLangs[i].value / total) * 100;
        legends.add(_buildLegendItem(name, _getLanguageColor(name), percentage, compact));
      } else {
        otherSum += sortedLangs[i].value;
      }
    }
    
    if (otherSum > 0) {
      final percentage = (otherSum / total) * 100;
      legends.add(_buildLegendItem('Others', const Color(0xFF94A3B8), percentage, compact));
    }
    
    return legends;
  }

  Widget _buildLegendItem(String name, Color color, double percentage, bool compact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 8 : 10,
            height: compact ? 8 : 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (repos.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Total Stars Earned
    final totalStars = repos.fold<int>(0, (sum, repo) => sum + repo.stargazersCount);

    // 2. Most Active Language
    final Map<String, int> langCounts = {};
    for (final r in repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final primaryLanguage = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'N/A';

    // 3. Contribution Streak
    final Map<int, int> daysActivity = {};
    final now = DateTime.now();
    for (final repo in repos) {
      final diff = now.difference(repo.pushedAt).inDays;
      if (diff >= 0 && diff < 365) {
        daysActivity[diff] = (daysActivity[diff] ?? 0) + 1;
      }
    }

    int currentStreak = 0;
    int checkDay = 0;
    bool hasActivityYesterday = (daysActivity[1] ?? 0) > 0;
    bool hasActivityToday = (daysActivity[0] ?? 0) > 0;

    if (hasActivityToday || hasActivityYesterday) {
      if (hasActivityToday) {
        currentStreak = 1;
        checkDay = 1;
      } else {
        currentStreak = 1;
        checkDay = 2;
      }
      while (true) {
        if ((daysActivity[checkDay] ?? 0) > 0) {
          currentStreak++;
          checkDay++;
        } else {
          break;
        }
      }
    }

    // 4. Repo Growth Data
    final sortedRepos = List<GhRepo>.from(repos)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final firstDate = sortedRepos.first.createdAt;
    final List<FlSpot> spots = [];
    for (int i = 0; i < sortedRepos.length; i++) {
      final days = sortedRepos[i].createdAt.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(days, (i + 1).toDouble()));
    }

    final maxX = spots.last.x;
    final maxY = sortedRepos.length.toDouble();

    // 5. Weekly Activity data
    final Map<int, int> weekdayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final repo in repos) {
      weekdayCounts[repo.pushedAt.weekday] = (weekdayCounts[repo.pushedAt.weekday] ?? 0) + 1;
    }
    
    final List<BarChartGroupData> barGroups = [];
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    int maxActivity = 0;
    for (int i = 1; i <= 7; i++) {
      final count = weekdayCounts[i] ?? 0;
      if (count > maxActivity) maxActivity = count;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), AppColors.accent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: compact ? 10 : 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    return AppSurface(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AppColors.accent,
                size: compact ? 18 : 22,
              ),
              const SizedBox(width: 8),
              Text(
                'GitPulse Analytics',
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metric Cards Grid
          Row(
            children: [
              _buildMetricCard(
                context,
                title: 'Total Stars',
                value: totalStars.toString(),
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
                compact: compact,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                context,
                title: 'Language',
                value: primaryLanguage,
                icon: Icons.code_rounded,
                iconColor: AppColors.accent,
                compact: compact,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                context,
                title: 'Streak',
                value: '$currentStreak Days',
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFEF4444),
                compact: compact,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Repo Growth Chart Title
          Text(
            'Repository Growth Over Time',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Growth Chart
          SizedBox(
            height: compact ? 100 : 130,
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'Not enough data to map growth.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY * 1.1,
                      minX: 0,
                      maxX: maxX,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: compact ? 22 : 28,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            interval: (maxX / 2).clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final date = firstDate.add(Duration(days: value.round()));
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  DateFormat('MMM yy').format(date),
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                          ),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF3B82F6).withValues(alpha: 0.25),
                                const Color(0xFF9333EA).withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          
          if (sortedLangs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(),
            ),
            Text(
              'Language Distribution',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: compact ? 100 : 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: compact ? 20 : 28,
                        sections: _buildPieSections(sortedLangs, compact),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildLegends(sortedLangs, compact),
                  ),
                ),
              ],
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          Text(
            'Weekly Push Activity',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: compact ? 100 : 130,
            child: BarChart(
              BarChartData(
                maxY: (maxActivity * 1.2).clamp(5, double.infinity),
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: compact ? 20 : 24,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final index = (value.toInt() - 1).clamp(0, 6);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            weekdays[index],
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool compact,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: compact ? 14 : 16, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
