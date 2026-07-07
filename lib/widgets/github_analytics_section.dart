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
          const SizedBox(height: 20),
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
            color: isDark ? Colors.white10 : Colors.black12,
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
