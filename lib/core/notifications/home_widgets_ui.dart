import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22), // GitHub dark theme color
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF30363D), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(user.login ?? 'Profile', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const Divider(color: Color(0xFF30363D)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WidgetStat(icon: Icons.people_alt_rounded, value: formatCount(user.followers ?? 0), label: 'Followers'),
                  _WidgetStat(icon: Icons.source_rounded, value: '${user.publicRepos ?? 0}', label: 'Repos'),
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
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF30363D), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text('Top Repository', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Text(topRepo.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(topRepo.description ?? 'No description provided.', style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(
                children: [
                  _WidgetStatRow(icon: Icons.star_border_rounded, value: formatCount(topRepo.stargazersCount), label: 'Stars'),
                  const SizedBox(width: 16),
                  _WidgetStatRow(icon: Icons.call_split_rounded, value: formatCount(topRepo.forksCount), label: 'Forks'),
                  const SizedBox(width: 16),
                  if (topRepo.language != null)
                    _WidgetStatRow(icon: Icons.circle, value: topRepo.language!, label: ''),
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
          width: 160,
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF30363D), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text('Impact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
              const Divider(color: Color(0xFF30363D)),
              Text('⭐ ${formatCount(totalStars)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('🍴 ${formatCount(totalForks)}', style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
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

    final colors = [Colors.blueAccent, Colors.orangeAccent, Colors.purpleAccent];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Container(
          width: 320,
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF30363D), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Top Languages', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
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
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: List.generate(top3.length, (i) {
                    return Expanded(
                      flex: top3[i].value, 
                      child: Container(height: 12, color: colors[i % colors.length])
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
