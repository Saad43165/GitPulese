import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/safe_page.dart';
import '../../core/network/dio_client.dart';

final publicGistsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getPublicGists();
});

class GistsScreen extends ConsumerWidget {
  const GistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gistsAsync = ref.watch(publicGistsProvider);

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'GitHub Gists Explorer',
              subtitle: 'Browse trending code snippets, gists, and micro-scripts',
            ),
            Expanded(
              child: gistsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.code_off_rounded,
                      title: 'No public Gists found',
                      subtitle: 'Pull down to refresh and retry',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(publicGistsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.md,
                        AppSpacing.pageHorizontal,
                        100,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final owner = item['owner'] as Map<String, dynamic>? ?? {};
                        final files = item['files'] as Map<String, dynamic>? ?? {};
                        final description = (item['description'] as String?)?.isNotEmpty == true
                            ? item['description'] as String
                            : 'No description provided';
                        final avatarUrl = owner['avatar_url'] as String? ?? '';
                        final ownerLogin = owner['login'] as String? ?? 'anonymous';
                        final htmlUrl = item['html_url'] as String? ?? '';
                        final fileNames = files.keys.toList();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ownerLogin,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${fileNames.length} file${fileNames.length > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (fileNames.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: fileNames.take(4).map((fileName) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.insert_drive_file_outlined, size: 12, color: AppColors.accent),
                                          const SizedBox(width: 4),
                                          Text(
                                            fileName,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: htmlUrl));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Gist URL copied to clipboard!')),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('Copy Link'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () {
                                      if (htmlUrl.isNotEmpty) {
                                        launchUrl(Uri.parse(htmlUrl), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('View Gist'),
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: GlowingIndicator(size: 32)),
                error: (e, _) => ErrorStateView(
                  message: e is GitHubApiException ? e.message : e.toString(),
                  onRetry: () => ref.invalidate(publicGistsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
