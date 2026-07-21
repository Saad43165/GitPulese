import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/premium_code_viewer.dart';
import '../../widgets/app_markdown.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/safe_page.dart';
import '../editor/ai_code_editor_screen.dart';

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
  bool _forceLoadFullFile = false;
  final GlobalKey _aiExplainKey = GlobalKey();
  
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // State management for chunked code explanation
  String? _explanationHtml;
  bool _loadingExplanation = false;
  String? _explanationError;
  int _currentOffset = 0; // Tracks line offset
  static const int _chunkSize = 3000; // Line count per chunk
  bool _explainInitialized = false;
  bool _copied = false;

  Future<void> _explainNextChunk(String fullContent) async {
    if (_loadingExplanation) return;
    setState(() {
      _loadingExplanation = true;
      _explanationError = null;
    });

    try {
      final filename = widget.filePath.split('/').last;
      final api = ref.read(groqApiServiceProvider);

      final lines = fullContent.split('\n');
      final remainingLines = lines.length - _currentOffset;
      if (remainingLines <= 0) {
        setState(() {
          _loadingExplanation = false;
        });
        return;
      }

      final isFirstChunk = _currentOffset == 0;
      final chunkLineCount = remainingLines > _chunkSize ? _chunkSize : remainingLines;
      
      final chunkList = lines.sublist(_currentOffset, _currentOffset + chunkLineCount);
      var chunk = chunkList.join('\n');

      if (!isFirstChunk && _explanationHtml != null) {
        final contextSummary = _explanationHtml!.length > 400
            ? _explanationHtml!.substring(0, 400)
            : _explanationHtml!;
        chunk = '// Context of previous analysis summary: $contextSummary...\n'
            '// Here is the next section of code to audit (Lines ${_currentOffset + 1} to ${_currentOffset + chunkLineCount}):\n'
            '$chunk';
      }

      final explanation = await api.explainCode(filename: filename, code: chunk);

      setState(() {
        if (isFirstChunk) {
          _explanationHtml = explanation;
        } else {
          _explanationHtml = '${_explanationHtml ?? ''}\n\n---\n\n### 🔄 Continued Analysis (Lines ${_currentOffset + 1} to ${_currentOffset + chunkLineCount})\n\n$explanation';
        }
        _currentOffset += chunkLineCount;
        _loadingExplanation = false;
      });
    } catch (e) {
      setState(() {
        _explanationError = e.toString();
        _loadingExplanation = false;
      });
    }
  }

  Widget _buildExplanationBody(String content) {
    if (!_explainInitialized) {
      _explainInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _explainNextChunk(content);
      });
    }

    if (_explanationHtml == null && _loadingExplanation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlowingIndicator(),
            SizedBox(height: 16),
            Text(
              'Analyzing code & auditing structure...', 
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_explanationHtml == null && _explanationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to analyze: $_explanationError', style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _explainNextChunk(content),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalLines = content.split('\n').length;
    final hasMore = totalLines > _currentOffset;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMarkdown(
            data: _explanationHtml ?? '',
            selectable: true,
          ),
          if (hasMore) ...[
            const SizedBox(height: 20),
            AppSurface(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'File was large. First $_currentOffset lines scanned.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingExplanation)
                    const Center(child: GlowingIndicator(size: 24))
                  else if (_explanationError != null) ...[
                    Text('Failed to fetch next section: $_explanationError', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _explainNextChunk(content),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry next section'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _explainNextChunk(content);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Continue (Scan Next Section)'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_ai_explain') ?? false;
      if (!seen && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          ShowcaseView.get().startShowCase([_aiExplainKey]);
          await prefs.setBool('seen_ai_explain', true);
        }
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
    const binaryExts = [
      'zip', 'tar', 'gz', 'exe', 'dll', 'so', 'dylib',
      'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'avi', 'mov',
      'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
      'odt', 'ods', 'odp', 'pages', 'numbers', 'key',
      'wasm', 'bin', 'dat', 'class', 'jar', 'apk', 'ipa',
    ];
    final isImage = imageExts.contains(ext);
    final isBinary = binaryExts.contains(ext);

    final explanationHeight = MediaQuery.of(context).size.height * 0.55;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(fileName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Only show the AI button for non-image, non-binary text files
          if (!isImage && !isBinary && !_showAiExplanation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Showcase(
                key: _aiExplainKey,
                title: 'AI Code Auditor',
                description: 'Leverage deep AI context to explain the structure, identify bugs, suggest performance refactors, and document functions in the selected file.',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
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
          if (!isImage && !isBinary)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit & Patch with AI',
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiCodeEditorScreen(
                      initialOwner: widget.owner,
                      initialRepo: widget.repoName,
                      initialPath: widget.filePath,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: isBinary
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 72,
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a binary file and cannot be previewed in-app.',
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        final ghUrl = Uri.parse(
                          'https://github.com/${widget.owner}/${widget.repoName}/blob/HEAD/${widget.filePath}',
                        );
                        launchUrl(ghUrl, mode: LaunchMode.inAppBrowserView);
                      },
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open on GitHub'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    ),
                  ],
                ),
              ),
            )
          : isImage
          ? Consumer(
              builder: (context, ref, _) {
                return ref.watch(fileBytesProvider((owner: widget.owner, repo: widget.repoName, path: widget.filePath))).when(
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
                );
              },
            )
          : Consumer(
              builder: (context, ref, _) {
                return ref.watch(fileContentProvider((owner: widget.owner, repo: widget.repoName, path: widget.filePath))).when(
                  data: (content) {
                    final characterLimit = 35000;
                    final isTooLarge = content.length > characterLimit;
                    final displayContent = (isTooLarge && !_forceLoadFullFile)
                        ? content.substring(0, characterLimit)
                        : content;

                    return Stack(
                      children: [
                        // Code Viewer (PremiumCodeViewer internally handles text selection)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: _showAiExplanation ? explanationHeight : 0,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isTooLarge && !_forceLoadFullFile)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Large file (${content.length} chars). Preview is limited for speed.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.accent,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _forceLoadFullFile = true;
                                            });
                                          },
                                          child: const Text('Load Full'),
                                        ),
                                      ],
                                    ),
                                  ),
                                PremiumCodeViewer(
                                  code: displayContent,
                                  language: widget.filePath.split('.').lastOrNull ?? '',
                                ),
                              ],
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
                            child: Container(
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
                                            if (_explanationHtml != null)
                                              IconButton(
                                                icon: Icon(
                                                  _copied ? Icons.check_circle_rounded : Icons.copy_all_rounded, 
                                                  size: 22,
                                                  color: _copied ? Colors.green : AppColors.accent,
                                                ),
                                                tooltip: 'Copy to Clipboard',
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: _explanationHtml!));
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
                                              onPressed: () {
                                                setState(() {
                                                  _showAiExplanation = false;
                                                  // Reset pagination state when closing explanation panel
                                                  _explanationHtml = null;
                                                  _currentOffset = 0;
                                                  _explainInitialized = false;
                                                  _loadingExplanation = false;
                                                  _explanationError = null;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildExplanationBody(content),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(child: GlowingIndicator(size: 32)),
                  error: (e, _) => Center(child: Text('Failed to load file: $e')),
                );
              },
            ),
      ),
    );
  }
}
