import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/glowing_indicator.dart';

final fileContentProvider = FutureProvider.autoDispose.family<String, ({String owner, String repo, String path})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return await api.getFileRawContent(args.owner, args.repo, args.path);
});

final fileBytesProvider = FutureProvider.autoDispose.family<Uint8List, ({String owner, String repo, String path})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return await api.getFileRawBytes(args.owner, args.repo, args.path);
});

final codeExplanationProvider = FutureProvider.autoDispose.family<String, ({String filename, String code})>((ref, args) async {
  final api = ref.watch(groqApiServiceProvider);
  return await api.explainCode(filename: args.filename, code: args.code);
});

class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({super.key, required this.owner, required this.repoName, required this.filePath});
  final String owner;
  final String repoName;
  final String filePath;

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  bool _showAiExplanation = false;
  final GlobalKey _aiExplainKey = GlobalKey();
  
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Local caching to avoid re-invoking the API on panel open/close
  String? _cachedExplanation;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_ai_explain') ?? false;
      if (!seen && mounted) {
        ShowCaseWidget.of(context).startShowCase([_aiExplainKey]);
        await prefs.setBool('seen_ai_explain', true);
      }
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = widget.filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    const imageExts = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'webp'];
    final isImage = imageExts.contains(ext);

    final explanationHeight = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Only show the AI button for non-image text files
          if (!isImage && !_showAiExplanation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Showcase(
                key: _aiExplainKey,
                description: 'Tap here to let AI explain this file and hunt for bugs!',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showAiExplanation = true);
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                    label: const Text(
                      'AI Explain', 
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isImage
          ? ref.watch(fileBytesProvider((owner: widget.owner, repo: widget.repoName, path: widget.filePath))).when(
              data: (bytes) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        maxScale: 5.0,
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: GlowingIndicator(size: 32)),
              error: (e, _) => Center(child: Text('Failed to load image: $e')),
            )
          : ref.watch(fileContentProvider((owner: widget.owner, repo: widget.repoName, path: widget.filePath))).when(
              data: (content) {
                return Stack(
                  children: [
                    // Code Viewer wrapped in SelectionArea to allow copy/select without scroll conflicts
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: _showAiExplanation ? explanationHeight : 0,
                      child: SelectionArea(
                        child: Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              notificationPredicate: (notif) => notif.depth == 1,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  constraints: BoxConstraints(
                                    minWidth: MediaQuery.of(context).size.width - 32,
                                  ),
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  child: Text(
                                    content,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      height: 1.5,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // AI Explanation Panel
                    if (_showAiExplanation)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: explanationHeight,
                        child: Consumer(
                          builder: (context, ref, _) {
                            // Fetch the explanation if we don't have it cached yet
                            final explanationAsync = ref.watch(codeExplanationProvider((
                              filename: widget.filePath.split('/').last, 
                              code: content
                            )));

                            // Update local cache once the async provider successfully resolves
                            if (explanationAsync.hasValue && _cachedExplanation == null) {
                              _cachedExplanation = explanationAsync.value;
                            }

                            final explanationText = _cachedExplanation ?? explanationAsync.valueOrNull;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                                border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'AI Code Audit & Explanation', 
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            // Copy Button (Appears only when explanation content is available)
                                            if (explanationText != null)
                                              IconButton(
                                                icon: Icon(
                                                  _copied ? Icons.check_circle_rounded : Icons.copy_all_rounded, 
                                                  size: 22,
                                                  color: _copied ? Colors.green : AppColors.accent,
                                                ),
                                                tooltip: 'Copy to Clipboard',
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: explanationText));
                                                  HapticFeedback.mediumImpact();
                                                  setState(() => _copied = true);
                                                  Future.delayed(const Duration(seconds: 2), () {
                                                    if (mounted) {
                                                      setState(() => _copied = false);
                                                    }
                                                  });
                                                },
                                              ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => setState(() => _showAiExplanation = false),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: explanationText != null 
                                        ? Markdown(
                                            data: explanationText,
                                            physics: const BouncingScrollPhysics(),
                                          )
                                        : explanationAsync.when(
                                            data: (explanation) => Markdown(
                                              data: explanation,
                                              physics: const BouncingScrollPhysics(),
                                            ),
                                            loading: () => const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  GlowingIndicator(),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'Analyzing code & hunting bugs...', 
                                                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            error: (e, _) => Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(AppSpacing.lg),
                                                child: Text('Failed to analyze: $e', style: const TextStyle(color: AppColors.danger)),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: GlowingIndicator(size: 32)),
              error: (e, _) => Center(child: Text('Failed to load file: $e')),
            ),
    );
  }
}
