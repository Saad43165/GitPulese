import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../widgets/glowing_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/repo_model.dart';
import '../../../providers/ai_providers.dart';

class StarHistoryChart extends ConsumerWidget {
  const StarHistoryChart({super.key, required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(starHistoryProvider(repo));

    return historyAsync.when(
      data: (points) {
        if (points.length < 2) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Not enough stargazer data to draw a growth chart yet.'),
          );
        }

        final firstDate = points.first.key;
        final spots = points
            .map((p) => FlSpot(
                  p.key.difference(firstDate).inDays.toDouble(),
                  p.value.toDouble(),
                ))
            .toList();

        final maxY = points.last.value.toDouble();
        final maxX = spots.last.x;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sampled from ${points.length} real stargazer timestamps',
              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.15,
                  minX: 0,
                  maxX: maxX,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(1, double.infinity),
                    getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          _compactNumber(value),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: (maxX / 3).clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final date = firstDate.add(Duration(days: value.round()));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('MMM yy').format(date), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.accent.withValues(alpha: 0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: GlowingIndicator(size: 24)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load star history: $e', style: TextStyle(color: Theme.of(context).hintColor)),
      ),
    );
  }

  String _compactNumber(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toInt().toString();
  }
}

