import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/dio_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';

final _contentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String owner, String repo, String path})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getRepoContents(args.owner, args.repo, args.path);
  },
);

class FileBrowserScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;
  final String currentPath;

  const FileBrowserScreen({
    super.key,
    required this.owner,
    required this.repoName,
    this.currentPath = '',
  });

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (owner: widget.owner, repo: widget.repoName, path: widget.currentPath);
    final contentsAsync = ref.watch(_contentsProvider(args));
    final isRoot = widget.currentPath.isEmpty;
    final breadcrumbs = _buildBreadcrumbs();

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.owner}/${widget.repoName}',
              style: const TextStyle(fontSize: 11, color: AppColors.accent),
            ),
            const Text('Files', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0D1117),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.invalidate(_contentsProvider(args)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb trail
          if (!isRoot)
            _BreadcrumbBar(
              owner: widget.owner,
              repoName: widget.repoName,
              breadcrumbs: breadcrumbs,
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Filter files…',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: contentsAsync.when(
              data: (items) {
                final sorted = _sort(items);
                final filtered = _query.isEmpty
                    ? sorted
                    : sorted.where((e) => (e['name'] as String).toLowerCase().contains(_query)).toList();

                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.folder_open_rounded,
                    title: _query.isNotEmpty ? 'No matches' : 'Empty directory',
                    subtitle: _query.isNotEmpty
                        ? 'No files match "$_query"'
                        : 'This directory has no files',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_contentsProvider(args)),
                  child: AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 300),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _FileEntry(
                              entry: filtered[i],
                              owner: widget.owner,
                              repoName: widget.repoName,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: GlowingIndicator(size: 32)),
              error: (e, _) => ErrorStateView(
                message: e is GitHubApiException ? e.message : 'Failed to load files',
                onRetry: () => ref.invalidate(_contentsProvider(args)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> items) {
    final dirs = items.where((e) => e['type'] == 'dir').toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final files = items.where((e) => e['type'] == 'file').toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return [...dirs, ...files];
  }

  List<String> _buildBreadcrumbs() {
    if (widget.currentPath.isEmpty) return [];
    return widget.currentPath.split('/');
  }
}

class _BreadcrumbBar extends StatelessWidget {
  final String owner;
  final String repoName;
  final List<String> breadcrumbs;

  const _BreadcrumbBar({required this.owner, required this.repoName, required this.breadcrumbs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Pop back to root — go back as many times as breadcrumb depth
              for (var i = 0; i < breadcrumbs.length; i++) {
                context.pop();
              }
            },
            child: const Icon(Icons.home_rounded, size: 14, color: AppColors.accent),
          ),
          for (var i = 0; i < breadcrumbs.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white24),
            ),
            GestureDetector(
              onTap: i == breadcrumbs.length - 1
                  ? null
                  : () {
                      final targetDepth = breadcrumbs.length - 1 - i;
                      for (var j = 0; j < targetDepth; j++) {
                        context.pop();
                      }
                    },
              child: Text(
                breadcrumbs[i],
                style: TextStyle(
                  fontSize: 12,
                  color: i == breadcrumbs.length - 1 ? Colors.white70 : AppColors.accent,
                  fontWeight: i == breadcrumbs.length - 1 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String owner;
  final String repoName;

  const _FileEntry({required this.entry, required this.owner, required this.repoName});

  @override
  Widget build(BuildContext context) {
    final name = entry['name'] as String;
    final type = entry['type'] as String;
    final path = entry['path'] as String;
    final size = entry['size'] as int?;
    final isDir = type == 'dir';

    return GestureDetector(
      onTap: () {
        if (isDir) {
          context.push(AppRoutes.fileBrowserPath(owner, repoName, path));
        } else {
          context.push(AppRoutes.filePath(owner, repoName, path));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            _FileIcon(name: name, isDir: isDir),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isDir ? Colors.white : Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: isDir ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: isDir ? null : 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isDir && size != null)
              Text(
                _formatSize(size),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            const SizedBox(width: 6),
            Icon(
              isDir ? Icons.chevron_right_rounded : Icons.open_in_new_rounded,
              size: 14,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _FileIcon extends StatelessWidget {
  final String name;
  final bool isDir;

  const _FileIcon({required this.name, required this.isDir});

  @override
  Widget build(BuildContext context) {
    if (isDir) {
      return const Icon(Icons.folder_rounded, color: Color(0xFFF0C040), size: 18);
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final (icon, color) = _iconForExt(ext);
    return Icon(icon, color: color, size: 18);
  }

  (IconData, Color) _iconForExt(String ext) {
    return switch (ext) {
      'dart' => (Icons.flutter_dash, const Color(0xFF54C5F8)),
      'js' || 'ts' || 'jsx' || 'tsx' => (Icons.javascript, const Color(0xFFF7DF1E)),
      'py' => (Icons.code, const Color(0xFF3572A5)),
      'java' || 'kt' => (Icons.coffee, const Color(0xFFB07219)),
      'swift' => (Icons.apple, const Color(0xFFFF6347)),
      'go' => (Icons.code, const Color(0xFF00ADD8)),
      'rs' => (Icons.code, const Color(0xFFDEA584)),
      'json' || 'yaml' || 'yml' || 'toml' => (Icons.data_object, const Color(0xFFCB9820)),
      'md' || 'mdx' => (Icons.article_rounded, Colors.white54),
      'html' || 'htm' => (Icons.html, const Color(0xFFE34F26)),
      'css' || 'scss' || 'sass' => (Icons.css, const Color(0xFF1572B6)),
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' || 'webp' => (Icons.image_rounded, Colors.pinkAccent),
      'pdf' => (Icons.picture_as_pdf_rounded, Colors.redAccent),
      'sh' || 'bash' || 'zsh' => (Icons.terminal_rounded, Colors.greenAccent),
      'lock' => (Icons.lock_outline_rounded, Colors.white38),
      'gitignore' || 'gitattributes' => (Icons.merge_type_rounded, Colors.orangeAccent),
      'xml' || 'plist' => (Icons.code, Colors.tealAccent),
      _ => (Icons.insert_drive_file_outlined, Colors.white38),
    };
  }
}
