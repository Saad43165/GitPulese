import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/premium_code_viewer.dart';
import '../../core/services/vault_file_manager.dart';
import '../../widgets/app_back_button.dart';
import '../editor/ai_code_editor_screen.dart';

class OfflineVaultRepo {
  final String name;
  final String owner;
  final String size;
  final int filesCount;
  final String downloadedAt;

  OfflineVaultRepo({
    required this.name,
    required this.owner,
    required this.size,
    required this.filesCount,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'owner': owner,
    'size': size,
    'filesCount': filesCount,
    'downloadedAt': downloadedAt,
  };

  factory OfflineVaultRepo.fromJson(Map<String, dynamic> json) => OfflineVaultRepo(
    name: json['name'],
    owner: json['owner'],
    size: json['size'],
    filesCount: json['filesCount'],
    downloadedAt: json['downloadedAt'],
  );
}

class OfflineVaultNotifier extends StateNotifier<List<OfflineVaultRepo>> {
  OfflineVaultNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('offline_vault_repos');
    if (list != null) {
      state = list.map((item) => OfflineVaultRepo.fromJson(jsonDecode(item))).toList();
    } else {
      state = [
        OfflineVaultRepo(
          name: 'flutter',
          owner: 'flutter',
          size: '14.2 MB',
          filesCount: 314,
          downloadedAt: '2 days ago',
        ),
        OfflineVaultRepo(
          name: 'react',
          owner: 'facebook',
          size: '8.7 MB',
          filesCount: 245,
          downloadedAt: '1 week ago',
        ),
      ];
    }
  }

  Future<void> addRepo(OfflineVaultRepo repo) async {
    // Remove if already exists first to avoid duplicates and update metadata
    state = state.where((r) => !(r.name.toLowerCase() == repo.name.toLowerCase() && r.owner.toLowerCase() == repo.owner.toLowerCase())).toList();
    state = [...state, repo];
    await _save();
  }

  Future<void> removeRepo(String owner, String name) async {
    state = state.where((r) => !(r.owner.toLowerCase() == owner.toLowerCase() && r.name.toLowerCase() == name.toLowerCase())).toList();
    await _save();
    
    // Clean up local filesystem cache for this repo
    await VaultFileManager.deleteRepo(owner, name);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('offline_vault_repos', list);
  }
}

final offlineVaultProvider = StateNotifierProvider<OfflineVaultNotifier, List<OfflineVaultRepo>>((ref) {
  return OfflineVaultNotifier();
});

class OfflineCodebaseVaultScreen extends ConsumerStatefulWidget {
  const OfflineCodebaseVaultScreen({super.key});

  @override
  ConsumerState<OfflineCodebaseVaultScreen> createState() => _OfflineCodebaseVaultScreenState();
}

class _OfflineCodebaseVaultScreenState extends ConsumerState<OfflineCodebaseVaultScreen> {
  final _searchController = TextEditingController();
  final _dialogOwnerController = TextEditingController();
  final _dialogRepoController = TextEditingController();
  
  String _searchQuery = '';
  bool _isSyncing = false;
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  List<GrepSearchResult> _grepResults = [];
  bool _isSearchingGrep = false;
  int _searchTypeIndex = 0; // 0 for Codebases, 1 for Grep Code

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      setState(() {
        _searchQuery = query;
      });
      if (query.isNotEmpty) {
        _runGrepSearch(query);
      }
    });
    _checkAndShowTutorial();
  }

  Future<void> _runGrepSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _grepResults = [];
        _isSearchingGrep = false;
      });
      return;
    }
    setState(() {
      _isSearchingGrep = true;
    });
    
    final repos = ref.read(offlineVaultProvider);
    final allResults = <GrepSearchResult>[];
    for (final repo in repos) {
      final results = await VaultFileManager.grepSearch(
        owner: repo.owner,
        repo: repo.name,
        query: query,
      );
      allResults.addAll(results);
    }
    
    if (mounted && _searchController.text.trim().toLowerCase() == query) {
      setState(() {
        _grepResults = allResults;
        _isSearchingGrep = false;
      });
    }
  }

  Widget _buildSearchTabButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _searchTypeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _searchTypeIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.accent.withValues(alpha: 0.15) 
                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.accent : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_vault_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _searchKey,
          _listKey,
        ]);
        await prefs.setBool('seen_vault_tutorial', true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dialogOwnerController.dispose();
    _dialogRepoController.dispose();
    super.dispose();
  }

  Future<void> _downloadRepoToVault(String owner, String repo) async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $owner/$repo to Offline Vault...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final api = ref.read(githubApiServiceProvider);
      final detail = await api.getRepoDetail(owner, repo);
      
      // 1. Fetch Git Tree recursively
      final treeData = await api.getGitTree(owner, repo);
      final treeList = treeData['tree'] as List<dynamic>? ?? [];

      // 2. Save tree structure to Local Filesystem
      await VaultFileManager.saveTree(owner, repo, treeList);

      // 3. Identify and pre-cache critical files in the background
      final criticalFiles = <String>[];
      for (final item in treeList) {
        if (item['type'] == 'blob') {
          final path = item['path'] as String;
          final name = path.split('/').last.toLowerCase();
          
          if (name == 'readme.md' || 
              name == 'pubspec.yaml' || 
              name == 'package.json' || 
              name == 'requirements.txt' ||
              name == 'main.dart' || 
              name == 'index.js' || 
              name == 'main.py' ||
              path == 'lib/main.dart' ||
              path == 'src/index.ts') {
            criticalFiles.add(path);
          }
        }
      }

      // Pre-download up to 10 critical code files
      int cachedFilesCount = 0;
      for (final filePath in criticalFiles.take(10)) {
        try {
          final fileContent = await api.getFileRawContent(owner, repo, filePath);
          await VaultFileManager.saveFile(owner, repo, filePath, fileContent);
          cachedFilesCount++;
        } catch (_) {}
      }

      final filesCount = treeList.where((item) => item['type'] == 'blob').length;
      final sizeMb = ((detail.size ?? 1200) / 1024).toStringAsFixed(1);

      final newRepo = OfflineVaultRepo(
        name: detail.name,
        owner: detail.owner.login,
        size: '$sizeMb MB',
        filesCount: filesCount,
        downloadedAt: 'Just now',
      );

      await ref.read(offlineVaultProvider.notifier).addRepo(newRepo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully cached $owner/$repo ($cachedFilesCount files synced) in Offline Vault!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showAddRepositorySheet(BuildContext context, bool isDark) {
    final authUser = ref.read(authenticatedUserProvider).valueOrNull;
    _dialogOwnerController.clear();
    _dialogRepoController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final userRepos = authUser != null
                  ? ref.watch(userReposProvider(authUser.login)).valueOrNull
                  : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add to Offline Vault',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This downloads the repository structure and critical source files locally for offline reading.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dialogOwnerController,
                          decoration: const InputDecoration(
                            labelText: 'Owner',
                            hintText: 'e.g. flutter',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dialogRepoController,
                          decoration: const InputDecoration(
                            labelText: 'Repository',
                            hintText: 'e.g. flutter',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final owner = _dialogOwnerController.text.trim();
                      final repo = _dialogRepoController.text.trim();
                      if (owner.isEmpty || repo.isEmpty) return;

                      Navigator.pop(context);
                      _downloadRepoToVault(owner, repo);
                    },
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: const Text('Download to Vault'),
                  ),
                  if (authUser != null && userRepos != null && userRepos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Your GitHub Repositories',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: userRepos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final repo = userRepos[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(repo.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.accent),
                            onTap: () {
                              Navigator.pop(context);
                              _downloadRepoToVault(authUser.login, repo.name);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusStat(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
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
            Icon(Icons.offline_pin_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Offline Code Vault'),
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
                'This screen allows you to download and cache repositories locally on your device to read, search, and navigate them completely offline.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Downloads Git trees recursively and indexes directories.\n'
                '• Caches file structures and key source files (READMEs, main entrypoints, configuration files).\n'
                '• Implements an offline regex-based query engine to locate code snippets locally.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Tap the "+" button in the top right to download a repository.\n'
                '2. Choose from your active repositories or search directly.\n'
                '3. Once cached, tap any repository card in the Vault to browse files and perform offline code search.',
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
    final vaultRepos = ref.watch(offlineVaultProvider);
    final filtered = vaultRepos.where((r) {
      return r.name.toLowerCase().contains(_searchQuery) ||
          r.owner.toLowerCase().contains(_searchQuery);
    }).toList();

    double totalSizeMb = 0;
    for (final repo in vaultRepos) {
      final sizeStr = repo.size.replaceAll(RegExp(r'[^\d\.]'), '');
      final sizeVal = double.tryParse(sizeStr) ?? 0.0;
      totalSizeMb += sizeVal;
    }

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Offline Code Vault'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'How to use this feature',
            ),
            if (_isSyncing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: GlowingIndicator(size: 20),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAddRepositorySheet(context, isDark),
              ),
          ],
        ),
        body: Column(
          children: [
            // High-fidelity Vault Capacity & Status Dashboard
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1B194B).withValues(alpha: 0.85), const Color(0xFF0C0E26).withValues(alpha: 0.95)]
                        : [const Color(0xFFEEF2FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VAULT ACTIVE',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accent,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${totalSizeMb.toStringAsFixed(1)} MB',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Total Local Space Utilized',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStatusStat(
                                'Codebases',
                                '${vaultRepos.length}',
                                Icons.folder_copy_rounded,
                                isDark,
                              ),
                              const SizedBox(width: 24),
                              _buildStatusStat(
                                'Files',
                                '${vaultRepos.fold(0, (sum, r) => sum + r.filesCount)}',
                                Icons.insert_drive_file_rounded,
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Circular Capacity Progress Indicator with neon ring
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: (vaultRepos.length / 10).clamp(0.0, 1.0),
                              strokeWidth: 8,
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${((vaultRepos.length / 10).clamp(0.0, 1.0) * 100).toInt()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'Capacity',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Showcase(
                key: _searchKey,
                title: 'Offline Search Engine',
                description: 'Search globally across all indexed offline codebase directories, code files, and symbols. Full local indexing works completely without an internet connection.',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131127) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search offline files or codebases...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accent),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131127) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSearchTabButton(0, 'Codebases', Icons.folder_copy_rounded, isDark),
                    _buildSearchTabButton(1, 'Grep Code', Icons.code_rounded, isDark),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _searchTypeIndex == 0
                  ? Showcase(
                      key: _listKey,
                      title: 'Offline Repositories Vault',
                      description: 'Explore all successfully cloned and compiled repositories. Tap any entry to traverse its local directories, inspect source files, or execute local queries.',
                      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                      tooltipBackgroundColor: const Color(0xFF1E293B),
                      tooltipBorderRadius: BorderRadius.circular(12),
                      blurValue: 2,
                      child: filtered.isEmpty
                          ? const Center(child: Text('No offline codebases match your search.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final repo = filtered[index];
                                return Dismissible(
                                  key: Key('${repo.owner}/${repo.name}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
                                  ),
                                  onDismissed: (_) {
                                    ref.read(offlineVaultProvider.notifier).removeRepo(repo.owner, repo.name);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Removed ${repo.name} from Offline Vault.')),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [const Color(0xFF1D1B3C), const Color(0xFF0F0D21)]
                                            : [Colors.white, const Color(0xFFF9FAFB)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => OfflineCodebaseReaderScreen(
                                                owner: repo.owner,
                                                repoName: repo.name,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Owner Initials Avatar Widget with gradient background
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [AppColors.accent, AppColors.accentSoft],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.accent.withValues(alpha: 0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  repo.owner.substring(0, repo.owner.length >= 2 ? 2 : 1).toUpperCase(),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      repo.name,
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.folder_outlined, size: 12, color: isDark ? Colors.white38 : Colors.black45),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '${repo.filesCount} files',
                                                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.sd_storage_outlined, size: 12, color: isDark ? Colors.white38 : Colors.black45),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                repo.size,
                                                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.sync_rounded, size: 20),
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                tooltip: 'Update Cache',
                                                onPressed: () {
                                                  _downloadRepoToVault(repo.owner, repo.name);
                                                },
                                              ),
                                              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    )
                  : _isSearchingGrep
                      ? const Center(child: GlowingIndicator())
                      : _grepResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black38),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty ? 'Type code query to search vault' : 'No matches found offline',
                                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: _grepResults.length,
                              itemBuilder: (context, index) {
                                final res = _grepResults[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [const Color(0xFF1D1B3C), const Color(0xFF0F0D21)]
                                          : [Colors.white, const Color(0xFFF9FAFB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => OfflineFileViewerScreen(
                                              owner: res.owner,
                                              repoName: res.repoName,
                                              filePath: res.filePath,
                                              initialHighlightLine: res.lineNumber,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent.withValues(alpha: 0.12),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.code_rounded, size: 14, color: AppColors.accent),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${res.owner}/${res.repoName} • ${res.filePath}',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white70 : Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Line ${res.lineNumber}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      color: AppColors.accent,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                                ),
                                              ),
                                              child: Text(
                                                res.lineContent.trim(),
                                                style: GoogleFonts.firaCode(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                  height: 1.3,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineCodebaseReaderScreen extends StatelessWidget {
  const OfflineCodebaseReaderScreen({
    super.key,
    required this.owner,
    required this.repoName,
  });

  final String owner;
  final String repoName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('$owner/$repoName (Offline)'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OfflineSourceCodeSection(owner: owner, repoName: repoName),
        ),
      ),
    );
  }
}

class OfflineSourceCodeSection extends ConsumerStatefulWidget {
  const OfflineSourceCodeSection({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  ConsumerState<OfflineSourceCodeSection> createState() => _OfflineSourceCodeSectionState();
}

class _OfflineSourceCodeSectionState extends ConsumerState<OfflineSourceCodeSection> {
  final List<String> _pathStack = ['']; // Empty string for root
  final _localSearchController = TextEditingController();
  String _localSearchQuery = '';
  List<dynamic> _treeList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _localSearchController.addListener(() {
      setState(() {
        _localSearchQuery = _localSearchController.text.trim().toLowerCase();
      });
    });
    _loadCachedTree();
  }

  @override
  void dispose() {
    _localSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedTree() async {
    final treeList = await VaultFileManager.loadTree(widget.owner, widget.repoName);
    if (treeList != null) {
      setState(() {
        _treeList = treeList;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _getDirectoryContents(String currentPath) {
    final List<Map<String, dynamic>> contents = [];
    final prefix = currentPath.isEmpty ? '' : '$currentPath/';

    for (final item in _treeList) {
      final path = item['path'] as String;
      if (path.startsWith(prefix)) {
        final subPath = path.substring(prefix.length);
        if (subPath.isNotEmpty && !subPath.contains('/')) {
          contents.add({
            'name': subPath,
            'path': path,
            'type': item['type'] == 'tree' ? 'dir' : 'file',
            'size': item['size'],
          });
        }
      }
    }
    return contents;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = _pathStack.last;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: GlowingIndicator(size: 24));
    }

    if (_treeList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: Text('No cached structure found. Please sync this repo online.')),
      );
    }

    final allItems = _getDirectoryContents(currentPath);

    // Filter items by local search query
    final items = allItems.where((item) {
      if (_localSearchQuery.isEmpty) return true;
      return (item['name'] as String).toLowerCase().contains(_localSearchQuery);
    }).toList();

    // Sort directories first, then files
    items.sort((a, b) {
      if (a['type'] == 'dir' && b['type'] != 'dir') return -1;
      if (a['type'] != 'dir' && b['type'] == 'dir') return 1;
      return (a['name'] as String).compareTo(b['name'] as String);
    });

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
                        _localSearchController.clear();
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

          // Local Directory Search Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _localSearchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Filter files in ${currentPath.isEmpty ? 'root' : currentPath.split('/').last}...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_localSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => _localSearchController.clear(),
                    child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                  ),
              ],
            ),
          ),

          if (items.isEmpty)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: Text('No matching items in directory')),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                itemBuilder: (context, index) {
                  final item = items[index];
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
                          _localSearchController.clear();
                          _pathStack.add(item['path'] as String);
                        });
                      } else {
                        final filePath = item['path'] as String;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OfflineFileViewerScreen(
                              owner: widget.owner,
                              repoName: widget.repoName,
                              filePath: filePath,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class OfflineFileViewerScreen extends ConsumerStatefulWidget {
  const OfflineFileViewerScreen({
    super.key,
    required this.owner,
    required this.repoName,
    required this.filePath,
    this.initialHighlightLine,
  });

  final String owner;
  final String repoName;
  final String filePath;
  final int? initialHighlightLine;

  @override
  ConsumerState<OfflineFileViewerScreen> createState() => _OfflineFileViewerScreenState();
}

class _OfflineFileViewerScreenState extends ConsumerState<OfflineFileViewerScreen> {
  String? _content;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    final cached = await VaultFileManager.loadFile(widget.owner, widget.repoName, widget.filePath);

    if (cached != null) {
      setState(() {
        _content = cached;
        _loading = false;
      });
      return;
    }

    // Try online fetch as fallback
    try {
      final api = ref.read(githubApiServiceProvider);
      final rawContent = await api.getFileRawContent(widget.owner, widget.repoName, widget.filePath);
      
      // Save to cache automatically for future offline use
      await VaultFileManager.saveFile(widget.owner, widget.repoName, widget.filePath, rawContent);

      setState(() {
        _content = rawContent;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = widget.filePath.split('/').last;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(fileName, style: const TextStyle(fontSize: 16)),
          actions: [
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
        body: _loading
            ? const Center(child: GlowingIndicator(size: 32))
            : _error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.danger.withValues(alpha: 0.7)),
                          const SizedBox(height: 16),
                          const Text(
                            'Offline File Unavailable',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This file was not pre-cached. Please connect to the internet to sync it.',
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: PremiumCodeViewer(
                      code: _content ?? '',
                      language: widget.filePath.split('.').lastOrNull ?? '',
                      highlightLineNumber: widget.initialHighlightLine,
                    ),
                  ),
      ),
    );
  }
}
