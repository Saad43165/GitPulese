import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../providers/repo_detail_providers.dart';
import '../../../../widgets/app_surface.dart';
import '../../../../widgets/glowing_indicator.dart';
import '../file_viewer_screen.dart';

class SourceCodeSection extends ConsumerStatefulWidget {
  const SourceCodeSection({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  ConsumerState<SourceCodeSection> createState() => _SourceCodeSectionState();
}

class _SourceCodeSectionState extends ConsumerState<SourceCodeSection> {
  final List<String> _pathStack = ['']; // Empty string for root

  @override
  Widget build(BuildContext context) {
    final currentPath = _pathStack.last;
    final contentsAsync = ref.watch(repoContentsProvider((owner: widget.owner, repo: widget.repoName, path: currentPath)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Path Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey[100],
              border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
            ),
            child: Row(
              children: [
                if (_pathStack.length > 1) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _pathStack.removeLast();
                      });
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                const Icon(Icons.folder_open_rounded, size: 20, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      currentPath.isEmpty ? widget.repoName : currentPath,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Files List
          contentsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: Text('Empty directory')),
                );
              }

              // Sort directories first, then files
              final sortedItems = List<Map<String, dynamic>>.from(items)
                ..sort((a, b) {
                  if (a['type'] == 'dir' && b['type'] != 'dir') return -1;
                  if (a['type'] != 'dir' && b['type'] == 'dir') return 1;
                  return (a['name'] as String).compareTo(b['name'] as String);
                });

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: sortedItems.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      final isDir = item['type'] == 'dir';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                          color: isDir ? AppColors.accent : (isDark ? Colors.white54 : Colors.black54),
                          size: 20,
                        ),
                        title: Text(
                          item['name'] as String,
                          style: TextStyle(
                            fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        trailing: isDir ? const Icon(Icons.chevron_right_rounded, size: 20) : null,
                        onTap: () {
                          if (isDir) {
                            setState(() {
                              _pathStack.add(item['path'] as String);
                            });
                          } else {
                            // Handle files
                            final fileName = item['name'] as String;
                            final ext = fileName.split('.').last.toLowerCase();
                            const imageExts = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'webp'];
                            // Binary/office formats: open in GitHub's browser viewer instead of trying to decode bytes as text
                            const binaryExts = [
                              'zip', 'tar', 'gz', 'exe', 'dll', 'so', 'dylib',
                              'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'avi', 'mov',
                              'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
                              'odt', 'ods', 'odp', 'pages', 'numbers', 'key',
                              'wasm', 'bin', 'dat', 'class', 'jar', 'apk', 'ipa',
                            ];
                            
                            if (binaryExts.contains(ext)) {
                              // Open on GitHub.com — it has a built-in viewer for Office, PDF, etc.
                              final ghUrl = Uri.parse('https://github.com/${widget.owner}/${widget.repoName}/blob/HEAD/${item['path']}');
                              launchUrl(ghUrl, mode: LaunchMode.inAppBrowserView);
                              return;
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FileViewerScreen(
                                  owner: widget.owner,
                                  repoName: widget.repoName,
                                  filePath: item['path'] as String,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: GlowingIndicator(size: 24)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Failed to load files: $e', style: const TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
