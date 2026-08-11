import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';

class FileEditorScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;
  final String filePath;
  // If null, we fetch them on load. Passed when already known (from file browser).
  final String? initialContent;
  final String? fileSha;
  final String? defaultBranch;

  const FileEditorScreen({
    super.key,
    required this.owner,
    required this.repoName,
    required this.filePath,
    this.initialContent,
    this.fileSha,
    this.defaultBranch,
  });

  @override
  ConsumerState<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends ConsumerState<FileEditorScreen> {
  final _contentController = TextEditingController();
  final _commitController = TextEditingController();
  final _scrollController = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _sha;
  String? _branch;
  String? _originalContent;

  // Tracks line count for the gutter
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
    _init();
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _commitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final lines = '\n'.allMatches(_contentController.text).length + 1;
    if (lines != _lineCount) setState(() => _lineCount = lines);
  }

  Future<void> _init() async {
    // If everything was pre-supplied, skip the network call.
    if (widget.initialContent != null && widget.fileSha != null && widget.defaultBranch != null) {
      _originalContent = widget.initialContent;
      _sha = widget.fileSha;
      _branch = widget.defaultBranch;
      _contentController.text = widget.initialContent!;
      _lineCount = '\n'.allMatches(widget.initialContent!).length + 1;
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final api = ref.read(githubApiServiceProvider);
      final results = await Future.wait([
        api.getFileMeta(widget.owner, widget.repoName, widget.filePath),
        api.getDefaultBranch(widget.owner, widget.repoName),
      ]);

      final meta = results[0] as Map<String, dynamic>?;
      final branch = results[1] as String;

      if (meta == null) {
        if (mounted) setState(() { _error = 'File not found.'; _loading = false; });
        return;
      }

      final size = meta['size'] as int? ?? 0;
      if (size > 500 * 1024) {
        if (mounted) setState(() { _error = 'File is too large to edit (> 500 KB).'; _loading = false; });
        return;
      }

      final encoding = meta['encoding'] as String?;
      final rawContent = meta['content'] as String?;

      String content;
      if (encoding == 'base64' && rawContent != null) {
        content = utf8.decode(base64.decode(rawContent.replaceAll('\n', '')));
      } else {
        content = rawContent ?? '';
      }

      if (mounted) {
        _originalContent = content;
        _sha = meta['sha'] as String?;
        _branch = branch;
        _contentController.text = content;
        _lineCount = '\n'.allMatches(content).length + 1;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load file: ${_cleanError(e)}'; _loading = false; });
    }
  }

  Future<void> _save() async {
    final content = _contentController.text;
    final message = _commitController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a commit message.')),
      );
      return;
    }

    if (content == _originalContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.')),
      );
      return;
    }

    if (_sha == null || _branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File metadata not loaded yet. Please wait.')),
      );
      return;
    }

    final confirmed = await _showConfirmDialog(message);
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(githubApiServiceProvider).updateFile(
        owner: widget.owner,
        repo: widget.repoName,
        path: widget.filePath,
        content: content,
        sha: _sha!,
        message: message,
        branch: _branch!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Committed to $_branch'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true); // signal success to caller
    } catch (e) {
      if (!mounted) return;
      final msg = _cleanError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _showConfirmDialog(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D1117),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Confirm commit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.owner}/${widget.repoName}',
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.filePath,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.commit, size: 14, color: Colors.white38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Branch: $_branch',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                child: const Text('Commit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'Permission denied — you need write access to this repository.';
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return 'Conflict — the file was updated remotely. Please reload.';
    }
    if (msg.contains('422')) {
      return 'Validation failed — check the file content and commit message.';
    }
    if (msg.contains('404')) {
      return 'File not found. It may have been deleted or moved.';
    }
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'Network error — check your internet connection.';
    }
    return 'Failed to save: please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (_contentController.text != _originalContent) {
              final discard = await _confirmDiscard() ?? false;
              if (discard && context.mounted) Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: const AppBackButton(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if (_branch != null)
              Text(_branch!, style: const TextStyle(fontSize: 10, color: AppColors.accent)),
          ],
        ),
        backgroundColor: const Color(0xFF0D1117),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy content',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _contentController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                );
              },
            ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(_saving ? 'Saving…' : 'Commit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: GlowingIndicator(size: 32))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _init(); })
              : Column(
                  children: [
                    // Commit message bar
                    Container(
                      color: const Color(0xFF0D1117),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _commitController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Commit message (required)',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                          prefixIcon: const Icon(Icons.commit, size: 16, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF161B22),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.accent),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF21262D)),
                    // Editor with line numbers
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line numbers gutter
                          Container(
                            width: 44,
                            color: const Color(0xFF0D1117),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  for (var i = 1; i <= _lineCount; i++)
                                    SizedBox(
                                      height: 20,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Text(
                                            '$i',
                                            style: const TextStyle(
                                              color: Colors.white24,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFF21262D)),
                          // Code editor
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                color: Color(0xFFE6EDF3),
                                fontSize: 13,
                                fontFamily: 'monospace',
                                height: 1.54,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.fromLTRB(12, 6, 12, 6),
                              ),
                              scrollController: _scrollController,
                              keyboardType: TextInputType.multiline,
                              autocorrect: false,
                              enableSuggestions: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<bool?> _confirmDiscard() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard changes?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have unsaved edits. Leave without committing?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
