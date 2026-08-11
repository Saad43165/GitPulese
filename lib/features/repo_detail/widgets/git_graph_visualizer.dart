import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_surface.dart';
import '../../../data/models/repo_model.dart';

class GitGraphVisualizer extends StatelessWidget {
  const GitGraphVisualizer({super.key, required this.commits});

  final List<GhCommit> commits;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (commits.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Git Tree & Commit Visualizer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${commits.length} Commits',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: commits.length,
            itemBuilder: (context, i) {
              final commit = commits[i];
              final isLast = i == commits.length - 1;
              final shortSha = commit.sha.length >= 7 ? commit.sha.substring(0, 7) : commit.sha;

              return SizedBox(
                height: 56,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Canvas Graph Tree Painter Column
                    SizedBox(
                      width: 32,
                      child: CustomPaint(
                        painter: _GitNodePainter(
                          isFirst: i == 0,
                          isLast: isLast,
                          color: i % 2 == 0 ? AppColors.accent : Colors.purpleAccent,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Commit details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  shortSha,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  commit.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${commit.authorName} • ${commit.date.toIso8601String().substring(0, 10)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GitNodePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final Color color;
  final bool isDark;

  _GitNodePainter({
    required this.isFirst,
    required this.isLast,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black26
      ..strokeWidth = 2.0;

    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final nodeOutlinePaint = Paint()
      ..color = isDark ? Colors.black : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = 20.0;

    if (!isLast) {
      canvas.drawLine(Offset(centerX, centerY), Offset(centerX, size.height), linePaint);
    }
    if (!isFirst) {
      canvas.drawLine(Offset(centerX, 0), Offset(centerX, centerY), linePaint);
    }

    canvas.drawCircle(Offset(centerX, centerY), 6.0, nodePaint);
    canvas.drawCircle(Offset(centerX, centerY), 6.0, nodeOutlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
