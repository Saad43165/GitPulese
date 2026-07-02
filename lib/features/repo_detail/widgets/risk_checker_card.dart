import 'package:flutter/material.dart';
import '../../../widgets/glowing_indicator.dart';
import '../../../widgets/expandable_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/repo_model.dart';
import '../../../providers/ai_providers.dart';

class RiskCheckerCard extends ConsumerWidget {
  const RiskCheckerCard({super.key, required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskAsync = ref.watch(dependencyRiskProvider(repo));

    return riskAsync.when(
      data: (result) {
        final manifest = result.manifest;
        final hasWarning = result.repoLicenseIsCopyleft;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasWarning)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${result.repoLicenseName} is a copyleft license — derivative/linked works may need to be open-sourced too. Review before using commercially.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            if (manifest == null)
              Text(
                'No pubspec.yaml, package.json, or requirements.txt found at the repo root.',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
              )
            else if (manifest.dependencies.isEmpty)
              Text('${manifest.manifestType} found, but no dependencies listed.', style: TextStyle(color: Theme.of(context).hintColor))
            else ...[
              Text(
                'Found ${manifest.dependencies.length} dependencies in ${manifest.manifestType}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              if (manifest.dependencies.length > 10)
                ExpandableSection(
                  collapsedHeight: 80,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: manifest.dependencies.map((d) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Text(
                          d.version != null ? '${d.name} ${d.version}' : d.name,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: manifest.dependencies.map((d) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        d.version != null ? '${d.name} ${d.version}' : d.name,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ],
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: GlowingIndicator(size: 24))),
      error: (e, _) => Text('Could not analyze dependencies: $e', style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }
}

