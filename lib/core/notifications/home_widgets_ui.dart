import 'package:flutter/material.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../../core/utils/formatters.dart';

class WidgetUiBuilder {
  static Widget buildOverview(dynamic user) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WidgetStat(icon: Icons.people_alt_rounded, value: formatCount(user.followers ?? 0), label: 'Followers'),
                  _WidgetStat(icon: Icons.person_add_rounded, value: formatCount(user.following ?? 0), label: 'Following'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WidgetStat(icon: Icons.source_rounded, value: '${user.publicRepos ?? 0}', label: 'Repos'),
                  _WidgetStat(icon: Icons.code_rounded, value: '${user.publicGists ?? 0}', label: 'Gists'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildTopRepo(GhRepo topRepo) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
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
                ],
              ),
              const Spacer(),
              Text(topRepo.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  _WidgetStatRow(icon: Icons.star_rounded, value: formatCount(topRepo.stargazersCount), label: 'Stars'),
                  const SizedBox(width: 16),
                  _WidgetStatRow(icon: Icons.call_split_rounded, value: formatCount(topRepo.forksCount), label: 'Forks'),
                  const SizedBox(width: 16),
                  if (topRepo.language != null)
                    _WidgetStatRow(icon: Icons.code_rounded, value: topRepo.language!, label: 'Lang'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildContribution(int totalStars, int totalForks) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Container(
          width: 320,
          height: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22), // forced dark
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF30363D), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded, color: Color(0xFF58A6FF), size: 20),
                      const SizedBox(width: 8),
                      const Text('Contributions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                  const Text('Impact', style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 64, color: Color(0xFFE3B341)),
                      const SizedBox(height: 16),
                      Text('⭐ ${formatCount(totalStars)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('🍴 ${formatCount(totalForks)}', style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
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

  static Widget buildLanguage(Map<String, int> langCounts) {
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedLangs.take(3).toList();
    final total = langCounts.values.fold(0, (sum, val) => sum + val);

    final colors = [Colors.blueAccent, Colors.orangeAccent, Colors.cyan];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(top3.length, (i) {
                  return _WidgetStatRow(
                    icon: Icons.circle, 
                    value: top3[i].key, 
                    label: '${((top3[i].value / total) * 100).toInt()}%'
                  );
                }),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: List.generate(top3.length, (i) {
                    return Expanded(
                      flex: top3[i].value, 
                      child: Container(height: 8, color: colors[i % colors.length])
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
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
