import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/ai_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/repo_detail_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';

class AiCodeEditorScreen extends ConsumerStatefulWidget {
  const AiCodeEditorScreen({
    super.key,
    this.initialOwner,
    this.initialRepo,
    this.initialPath,
  });

  final String? initialOwner;
  final String? initialRepo;
  final String? initialPath;

  @override
  ConsumerState<AiCodeEditorScreen> createState() => _AiCodeEditorScreenState();
}

class _AiCodeEditorScreenState extends ConsumerState<AiCodeEditorScreen> {
  final _codeController = TextEditingController(text: '''// Existing Code
void calculateSum() {
  int total = 0;
  for (int i = 0; i < 100; i++) {
    total += i;
  }
  print(total);
}''');

  final _promptController = TextEditingController(text: 'Refactor this code to be more Dart-idiomatic and performant.');
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _pathController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');

  String _diffOutput = '';
  bool _isLoading = false;
  bool _showDiff = false;
  bool _isCommitted = false;

  String? _loadedFileSha;
  bool _isFileLoaded = false;

  String? _selectedRepoOwner;
  String? _selectedRepoName;

  final GlobalKey _editorKey = GlobalKey();
  final GlobalKey _promptKey = GlobalKey();
  final GlobalKey _actionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialOwner != null) _ownerController.text = widget.initialOwner!;
    if (widget.initialRepo != null) _repoController.text = widget.initialRepo!;
    if (widget.initialPath != null) {
      _pathController.text = widget.initialPath!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchFile();
      });
    }
    _checkAndShowTutorial();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _promptController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _pathController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_ai_editor_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _editorKey,
          _promptKey,
          _actionKey,
        ]);
        await prefs.setBool('seen_ai_editor_tutorial', true);
      }
    }
  }

  Future<void> _fetchFile() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    final path = _pathController.text.trim();
    final branch = _branchController.text.trim();

    if (owner.isEmpty || repo.isEmpty || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill owner, repo, and file path fields.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showDiff = false;
      _isCommitted = false;
    });

    try {
      final api = ref.read(githubApiServiceProvider);
      final details = await api.getFileDetails(owner, repo, path, ref: branch);
      
      final contentBase64 = details['content'] as String? ?? '';
      final sha = details['sha'] as String? ?? '';
      
      // Decode content
      final cleanBase64 = contentBase64.replaceAll(RegExp(r'\s+'), '');
      final decodedContent = utf8.decode(base64.decode(cleanBase64));

      setState(() {
        _codeController.text = decodedContent;
        _loadedFileSha = sha;
        _isFileLoaded = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded $path successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load file: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refactor() async {
    setState(() {
      _isLoading = true;
      _showDiff = false;
    });

    try {
      final groq = ref.read(groqApiServiceProvider);
      final result = await groq.explainCode(
        filename: _pathController.text.trim().isNotEmpty ? _pathController.text.trim() : 'refactor_instructions.dart',
        code: 'Code to refactor:\n${_codeController.text}\n\nInstructions:\n${_promptController.text}\n\nReturn ONLY the refactored code without any explanations or markdown wrappers.',
      );

      // Clean markdown code blocks from response
      var cleanCode = result.replaceAll('```dart', '').replaceAll('```', '').trim();

      setState(() {
        _diffOutput = cleanCode;
        _showDiff = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Refactoring failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _commit() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    final path = _pathController.text.trim();
    final branch = _branchController.text.trim();

    if (!_isFileLoaded || _loadedFileSha == null) {
      // Fallback/Mock commit if they edited the default scratchpad file
      setState(() {
        _isLoading = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isLoading = false;
        _isCommitted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scratchpad patch simulated successfully! Connect to a repository to commit for real.')),
      );
      return;
    }

    // Prompt user for commit message
    final msgController = TextEditingController(text: 'Refactor $path using GitPulse AI');
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit Message'),
        content: TextField(
          controller: msgController,
          decoration: const InputDecoration(
            hintText: 'Enter commit message...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, msgController.text.trim()),
            child: const Text('Commit'),
          ),
        ],
      ),
    );

    if (message == null || message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final api = ref.read(githubApiServiceProvider);
      final response = await api.updateFile(
        owner: owner,
        repo: repo,
        path: path,
        content: _diffOutput, // the refactored code output
        sha: _loadedFileSha!,
        message: message,
        branch: branch,
      );

      final newSha = response['content']?['sha'] as String? ?? _loadedFileSha;

      setState(() {
        _loadedFileSha = newSha;
        _codeController.text = _diffOutput;
        _showDiff = false;
        _isCommitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patch applied and committed successfully to remote repository!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to commit file: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Widget> _buildDiffWidgets(String oldText, String newText) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final List<Widget> widgets = [];

    int i = 0;
    int j = 0;

    while (i < oldLines.length || j < newLines.length) {
      if (i < oldLines.length && j < newLines.length) {
        if (oldLines[i] == newLines[j]) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
            child: Text(
              '  ${oldLines[i]}',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ));
          i++;
          j++;
        } else {
          int nextMatchInNew = -1;
          for (int k = j; k < newLines.length; k++) {
            if (newLines[k] == oldLines[i]) {
              nextMatchInNew = k;
              break;
            }
          }

          if (nextMatchInNew != -1) {
            for (int k = j; k < nextMatchInNew; k++) {
              widgets.add(Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
                color: Colors.green.withValues(alpha: 0.15),
                child: Text(
                  '+ ${newLines[k]}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.greenAccent,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ));
            }
            j = nextMatchInNew;
          } else {
            widgets.add(Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
              color: Colors.red.withValues(alpha: 0.15),
              child: Text(
                '- ${oldLines[i]}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.redAccent,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ));
            i++;
          }
        }
      } else if (i < oldLines.length) {
        widgets.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
          color: Colors.red.withValues(alpha: 0.15),
          child: Text(
            '- ${oldLines[i]}',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.redAccent,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
        i++;
      } else if (j < newLines.length) {
        widgets.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
          color: Colors.green.withValues(alpha: 0.15),
          child: Text(
            '+ ${newLines[j]}',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.greenAccent,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
        j++;
      }
    }

    return widgets;
  }

  void _showFileSelectorSheet(BuildContext context, String owner, String repo, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _FileSelectorDialog(
          owner: owner,
          repoName: repo,
          isDark: isDark,
          onFileSelected: (filePath) {
            setState(() {
              _pathController.text = filePath;
            });
            _fetchFile();
          },
        );
      },
    );
  }

  Widget _buildRepositorySelector(bool isDark, GhUser? authUser) {
    final List<Map<String, dynamic>> popularRepos = [
      {'owner': 'flutter', 'name': 'flutter', 'label': 'Flutter', 'icon': Icons.flutter_dash_rounded},
      {'owner': 'facebook', 'name': 'react', 'label': 'React', 'icon': Icons.code_rounded},
      {'owner': 'dart-lang', 'name': 'sdk', 'label': 'Dart SDK', 'icon': Icons.terminal_rounded},
      {'owner': 'microsoft', 'name': 'vscode', 'label': 'VS Code', 'icon': Icons.desktop_mac_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Repository to Edit',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...popularRepos.map((repo) {
                final isSelected = _selectedRepoOwner == repo['owner'] && _selectedRepoName == repo['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRepoOwner = repo['owner'];
                        _selectedRepoName = repo['name'];
                        _ownerController.text = repo['owner'];
                        _repoController.text = repo['name'];
                      });
                      _showFileSelectorSheet(context, repo['owner'], repo['name'], isDark);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.accent.withValues(alpha: 0.15) 
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : (isDark ? Colors.white10 : Colors.black12),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(repo['icon'] as IconData, color: isSelected ? AppColors.accent : Colors.grey, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            repo['label'] as String,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (authUser != null)
                Consumer(
                  builder: (context, ref, _) {
                    final reposAsync = ref.watch(userReposProvider(authUser.login));
                    return reposAsync.when(
                      data: (repos) {
                        return Row(
                          children: repos.map((repo) {
                            final isSelected = _selectedRepoOwner == authUser.login && _selectedRepoName == repo.name;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedRepoOwner = authUser.login;
                                    _selectedRepoName = repo.name;
                                    _ownerController.text = authUser.login;
                                    _repoController.text = repo.name;
                                  });
                                  _showFileSelectorSheet(context, authUser.login, repo.name, isDark);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 90,
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? AppColors.accent.withValues(alpha: 0.15) 
                                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? AppColors.accent : (isDark ? Colors.white10 : Colors.black12),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.source_rounded, color: Colors.blueAccent, size: 24),
                                      const SizedBox(height: 6),
                                      Text(
                                        repo.name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: GlowingIndicator(size: 16))),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('AI Code Editor'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is this feature?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'This screen provides an interactive editing environment where you can request AI-driven code refactoring, view code diffs, and commit changes back to your GitHub repository.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Loads remote codebases using the GitHub Contents API.\n'
                '• Runs optimization instructions through the Groq coding assistant model to isolate refactored segments.\n'
                '• Computes side-by-side unified git diff boundaries.\n'
                '• Updates branches with custom commits using GitHub API.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Select a repository to pull files or configure paths manually.\n'
                '2. Choose a file path and load its contents into the editor.\n'
                '3. Type your instructions (e.g. "Add validation", "Convert loops") in the AI Prompt field and click Analyze.\n'
                '4. Verify additions/subtractions in the Diff panel, click "Apply Patch & Commit" to push changes.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('AI Code Editor & Git Patch'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'How to use this feature',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                setState(() {
                  _showDiff = false;
                  _isCommitted = false;
                });
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRepositorySelector(isDark, ref.watch(authenticatedUserProvider).valueOrNull),
              const SizedBox(height: AppSpacing.md),
              AppSurface(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Icon(
                        _isFileLoaded ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: _isFileLoaded ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isFileLoaded ? 'Connected: ${_repoController.text}' : 'Fetch Remote File (Optional)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _isFileLoaded
                        ? 'Editing real file on branch ${_branchController.text}'
                        : 'Connect to a real GitHub repo to read & write commits.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  childrenPadding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ownerController,
                            decoration: const InputDecoration(
                              labelText: 'Owner / Org',
                              hintText: 'e.g. flutter',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _repoController,
                            decoration: const InputDecoration(
                              labelText: 'Repository',
                              hintText: 'e.g. flutter',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _pathController,
                            decoration: const InputDecoration(
                              labelText: 'File Path',
                              hintText: 'e.g. README.md',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _branchController,
                            decoration: const InputDecoration(
                              labelText: 'Branch',
                              hintText: 'e.g. main',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _fetchFile,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Fetch File Content'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Source Editor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Showcase(
                key: _editorKey,
                title: 'High-Fidelity Code Editor',
                description: 'View, edit, or paste your source code inside this full-fledged monospace environment. Supports syntax highlights and real-time editing.',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
                child: AppSurface(
                  child: TextField(
                    controller: _codeController,
                    minLines: 12,
                    maxLines: 24,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'AI Refactor Prompt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Showcase(
                key: _promptKey,
                title: 'AI Refactoring Prompt',
                description: 'Instruct the AI on what you want to achieve, e.g., "Implement error handling", "Refactor to use patterns", or "Optimize loops".',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
                child: AppSurface(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _refactor,
                  icon: _isLoading
                      ? const GlowingIndicator(size: 18)
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Analyze & Generate Patch'),
                ),
              ),
              if (_showDiff) ...[
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Visual Git Patch (Diff)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          const Text('Removed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            width: 10,
                            height: 10,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 6),
                          const Text('Added', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        '@@ Inline Code Change Diff @@',
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._buildDiffWidgets(_codeController.text, _diffOutput),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Showcase(
                  key: _actionKey,
                  title: 'Apply Patch & Commit',
                  description: 'Commit your modified code directly to the repository branch, updating the code base in real-time.',
                  titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  tooltipBackgroundColor: const Color(0xFF1E293B),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  blurValue: 2,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading || _isCommitted ? null : _commit,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(_isCommitted ? 'Committed!' : 'Apply Patch & Commit'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSelectorDialog extends ConsumerStatefulWidget {
  const _FileSelectorDialog({
    required this.owner,
    required this.repoName,
    required this.isDark,
    required this.onFileSelected,
  });

  final String owner;
  final String repoName;
  final bool isDark;
  final ValueChanged<String> onFileSelected;

  @override
  ConsumerState<_FileSelectorDialog> createState() => _FileSelectorDialogState();
}

class _FileSelectorDialogState extends ConsumerState<_FileSelectorDialog> {
  final List<String> _pathStack = [''];

  @override
  Widget build(BuildContext context) {
    final currentPath = _pathStack.last;
    final contentsAsync = ref.watch(repoContentsProvider((owner: widget.owner, repo: widget.repoName, path: currentPath)));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_pathStack.length > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        setState(() {
                          _pathStack.removeLast();
                        });
                      },
                    ),
                  ],
                  const Icon(Icons.folder_open_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentPath.isEmpty ? widget.repoName : currentPath,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: contentsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('Empty directory'));
                  }

                  final sortedItems = List<Map<String, dynamic>>.from(items)
                    ..sort((a, b) {
                      if (a['type'] == 'dir' && b['type'] != 'dir') return -1;
                      if (a['type'] != 'dir' && b['type'] == 'dir') return 1;
                      return (a['name'] as String).compareTo(b['name'] as String);
                    });

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: sortedItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      final isDir = item['type'] == 'dir';

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                          color: isDir ? AppColors.accent : Colors.grey,
                          size: 20,
                        ),
                        title: Text(item['name'] as String),
                        trailing: isDir ? const Icon(Icons.chevron_right_rounded, size: 16) : null,
                        onTap: () {
                          if (isDir) {
                            setState(() {
                              _pathStack.add(item['path'] as String);
                            });
                          } else {
                            Navigator.pop(context);
                            widget.onFileSelected(item['path'] as String);
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: GlowingIndicator()),
                error: (e, _) => Center(child: Text('Failed to load files: $e', style: const TextStyle(color: Colors.redAccent))),
              ),
            ),
          ],
        );
      },
    );
  }
}
