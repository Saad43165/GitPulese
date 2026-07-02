import 'package:flutter/material.dart';
import '../../../widgets/glowing_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/repo_model.dart';
import '../../../providers/ai_providers.dart';
import '../../../widgets/repo_card.dart';
import '../../../core/theme/app_spacing.dart';
import '../repo_detail_screen.dart';

class SimilarReposSection extends ConsumerWidget {
  const SimilarReposSection({super.key, required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarReposProvider(repo));

    return similarAsync.when(
      data: (repos) {
        if (repos.isEmpty) {
          return Text(
            'No close alternatives found from this repo\'s topics/language.',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          );
        }
        return SizedBox(
          height: 135,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: repos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final r = repos[i];
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 280,
                  child: RepoCard(
                    repo: r,
                    compact: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RepoDetailScreen(owner: r.owner.login, repoName: r.name)),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: GlowingIndicator(size: 24))),
      error: (e, _) => Text('Could not find alternatives: $e', style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }
}

