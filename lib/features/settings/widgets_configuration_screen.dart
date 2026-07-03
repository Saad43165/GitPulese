import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';

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
                    const _SectionHeader(title: 'Contribution Graph (Large)', subtitle: 'Your 30-day commit heat map.'),
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
    return Center(
      child: Container(
        width: 160,
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333EA).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 8),
                const Text('GitPulse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WidgetStat(icon: Icons.commit_rounded, value: '14', label: 'Commits'),
                _WidgetStat(icon: Icons.source_rounded, value: '2', label: 'PRs'),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WidgetStat(icon: Icons.star_rounded, value: '45', label: 'Stars'),
                _WidgetStat(icon: Icons.error_outline_rounded, value: '1', label: 'Issues'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreview2 extends StatelessWidget {
  const _WidgetPreview2();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.folder_outlined, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Top Repository', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Healthy', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Spacer(),
            const Text('gitexplorer-app', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Row(
              children: [
                _WidgetStatRow(icon: Icons.star_rounded, value: '1.2k', label: 'Stars'),
                SizedBox(width: 16),
                _WidgetStatRow(icon: Icons.call_split_rounded, value: '340', label: 'Forks'),
                SizedBox(width: 16),
                _WidgetStatRow(icon: Icons.code_rounded, value: 'Dart', label: 'Language'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreview3 extends StatelessWidget {
  const _WidgetPreview3();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Contributions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const Text('30 Days', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: 35, // 5 weeks
                itemBuilder: (context, index) {
                  // Simulate heatmap colors
                  final intensity = (index * 7 + 13) % 5;
                  Color cellColor;
                  if (intensity == 0) {
                    cellColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF21262D) : const Color(0xFFEBEDF0);
                  } else if (intensity == 1) {
                    cellColor = const Color(0xFF9BE9A8);
                  } else if (intensity == 2) {
                    cellColor = const Color(0xFF40C463);
                  } else if (intensity == 3) {
                    cellColor = const Color(0xFF30A14E);
                  } else {
                    cellColor = const Color(0xFF216E39);
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('148 total commits', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text('Less', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                    const SizedBox(width: 4),
                    const _HeatBox(Color(0xFFEBEDF0)),
                    const _HeatBox(Color(0xFF9BE9A8)),
                    const _HeatBox(Color(0xFF40C463)),
                    const _HeatBox(Color(0xFF30A14E)),
                    const _HeatBox(Color(0xFF216E39)),
                    const SizedBox(width: 4),
                    Text('More', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatBox extends StatelessWidget {
  const _HeatBox(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _WidgetStat extends StatelessWidget {
  const _WidgetStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _WidgetStatRow extends StatelessWidget {
  const _WidgetStatRow({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }
}

class _WidgetPreview4 extends StatelessWidget {
  const _WidgetPreview4();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text('Top Languages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WidgetStatRow(icon: Icons.circle, value: 'Dart', label: '54%'),
                _WidgetStatRow(icon: Icons.circle, value: 'Swift', label: '30%'),
                _WidgetStatRow(icon: Icons.circle, value: 'Go', label: '16%'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(flex: 54, child: Container(height: 8, color: Colors.blueAccent)),
                  Expanded(flex: 30, child: Container(height: 8, color: Colors.orangeAccent)),
                  Expanded(flex: 16, child: Container(height: 8, color: Colors.cyan)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

