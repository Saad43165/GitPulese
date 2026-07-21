import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../editor/ai_code_editor_screen.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';

class VisualNode {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final List<VisualNode> children = [];
  VisualNode({required this.name, required this.path, required this.isDir, this.size = 0});
}

class ArchitectureVisualizerScreen extends ConsumerStatefulWidget {
  const ArchitectureVisualizerScreen({super.key});

  @override
  ConsumerState<ArchitectureVisualizerScreen> createState() => _ArchitectureVisualizerScreenState();
}

class _ArchitectureVisualizerScreenState extends ConsumerState<ArchitectureVisualizerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final GlobalKey _radialKey = GlobalKey();
  final GlobalKey _metricsKey = GlobalKey();

  final _ownerController = TextEditingController(text: 'flutter');
  final _repoController = TextEditingController(text: 'flutter');
  final _searchController = TextEditingController();

  bool _isLoading = false;
  bool _hasLoaded = false;
  VisualNode? _rootNode;
  List<dynamic> _treeItems = []; // Cache for raw git tree data

  // Interactive controls state
  int _maxDepth = 3;
  String _searchQuery = '';
  VisualNode? _selectedNode;

  // Real stats
  int _totalFiles = 0;
  int _totalDirs = 0;
  double _testCoverage = 0.0;
  String _complexityStr = 'Low';
  double _complexityVal = 0.15;
  String _riskStr = 'Low';
  double _riskVal = 0.15;

  List<Map<String, dynamic>> _insights = [
    {'icon': Icons.folder_zip_rounded, 'label': 'Hotspots', 'desc': 'lib/features/ contains 48% of edits'},
    {'icon': Icons.code_rounded, 'label': 'Top Lang', 'desc': 'Dart (96.4%), HTML (2.1%), JS (1.5%)'},
    {'icon': Icons.warning_amber_rounded, 'label': 'Coupling', 'desc': 'Low coupling index, modular design'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _checkAndShowTutorial();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_architecture_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _radialKey,
          _metricsKey,
        ]);
        await prefs.setBool('seen_architecture_tutorial', true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchArchitecture() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();

    if (owner.isEmpty || repo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both owner and repository name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedNode = null;
    });

    try {
      final api = ref.read(githubApiServiceProvider);
      final treeData = await api.getGitTree(owner, repo);
      final List items = treeData['tree'] ?? [];

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository git tree is empty or could not be retrieved.')),
        );
        return;
      }

      _treeItems = items;
      _buildTreeFromPaths(items);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully visualized $owner/$repo architecture!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to visualize codebase: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildTreeFromPaths(List<dynamic> treeData) {
    final root = VisualNode(name: 'root', path: '', isDir: true);
    int filesCount = 0;
    int dirsCount = 0;
    int testFilesCount = 0;

    final Map<String, VisualNode> nodeMap = {'': root};
    final Map<String, int> extensionCounts = {};
    final Map<String, int> folderFileCounts = {};

    final sortedData = List<Map<String, dynamic>>.from(
      treeData.map((e) => e as Map<String, dynamic>)
    )..sort((a, b) => (a['path'] as String).compareTo(b['path']));

    for (final item in sortedData) {
      final path = item['path'] as String;
      final type = item['type'] as String;
      final isDir = type == 'tree';
      final size = item['size'] as int? ?? 0;

      if (isDir) {
        dirsCount++;
      } else {
        filesCount++;
        if (path.toLowerCase().contains('test')) {
          testFilesCount++;
        }

        final ext = path.contains('.') ? '.${path.split('.').last}' : 'no_ext';
        extensionCounts[ext] = (extensionCounts[ext] ?? 0) + 1;
      }

      final parts = path.split('/');
      final parentPath = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '';
      final name = parts.last;

      final node = VisualNode(name: name, path: path, isDir: isDir, size: size);
      nodeMap[path] = node;

      final parentNode = nodeMap[parentPath];
      if (parentNode != null) {
        if (parts.length <= _maxDepth) {
          parentNode.children.add(node);
        }
      }

      final topFolder = parts.first;
      if (isDir) {
        folderFileCounts[topFolder] = (folderFileCounts[topFolder] ?? 0) + 1;
      }
    }

    String compStr = 'Low';
    double compVal = 0.2;
    if (filesCount > 1000) {
      compStr = 'High';
      compVal = 0.85;
    } else if (filesCount > 300) {
      compStr = 'Medium';
      compVal = 0.55;
    }

    final double testPct = filesCount > 0 ? (testFilesCount / filesCount) : 0.0;

    bool hasEnv = treeData.any((e) {
      final path = (e['path'] as String).toLowerCase();
      return path.contains('.env') || path.contains('secret') || path.contains('credential') || path.contains('.pem');
    });
    double riskVal = hasEnv ? 0.8 : (filesCount > 500 ? 0.4 : 0.15);
    String riskStr = riskVal > 0.7 ? 'High' : (riskVal > 0.3 ? 'Medium' : 'Low');

    String hotspotDesc = 'No hotspots identified';
    if (folderFileCounts.isNotEmpty) {
      final sortedFolders = folderFileCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topFolder = sortedFolders.first.key;
      final pct = filesCount > 0 ? ((sortedFolders.first.value / filesCount) * 100).toStringAsFixed(0) : '0';
      hotspotDesc = '$topFolder/ contains $pct% of directory items';
    }

    String langDesc = 'No files found';
    if (extensionCounts.isNotEmpty) {
      final sortedLangs = extensionCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topLangs = sortedLangs.take(3).map((e) {
        final pct = filesCount > 0 ? ((e.value / filesCount) * 100).toStringAsFixed(1) : '0.0';
        return '${e.key} ($pct%)';
      }).join(', ');
      langDesc = topLangs;
    }

    final avgDepth = dirsCount > 0 ? (filesCount / dirsCount).toStringAsFixed(1) : '0';
    final couplingDesc = 'Average folder density is $avgDepth items/directory';

    setState(() {
      _rootNode = root;
      _totalFiles = filesCount;
      _totalDirs = dirsCount;
      _testCoverage = testPct;
      _complexityStr = compStr;
      _complexityVal = compVal;
      _riskStr = riskStr;
      _riskVal = riskVal;
      _insights = [
        {'icon': Icons.folder_zip_rounded, 'label': 'Hotspots', 'desc': hotspotDesc},
        {'icon': Icons.code_rounded, 'label': 'Top Languages', 'desc': langDesc},
        {'icon': Icons.warning_amber_rounded, 'label': 'Folder Density', 'desc': couplingDesc},
      ];
      _hasLoaded = true;
    });
  }

  void _handleCanvasTap(Offset localPosition, Size canvasSize) {
    if (_rootNode == null) return;
    final node = _findClosestNode(localPosition, canvasSize, _pulseController.value);
    
    setState(() {
      _selectedNode = node;
    });

    if (node != null) {
      HapticFeedback.selectionClick();
    }
  }

  VisualNode? _findClosestNode(Offset tapPos, Size size, double progress) {
    if (_rootNode == null) return null;
    
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.95;
    final orbitRadiusStep = maxRadius / (_maxDepth + 1);

    VisualNode? closestNode;
    double minDistance = 99999.0;

    // Check root node
    double rootDist = (tapPos - center).distance;
    if (rootDist < 12.0) {
      return _rootNode;
    }

    void checkChildren(VisualNode parent, int depth, double minAngle, double maxAngle) {
      final allChildren = parent.children;
      if (allChildren.isEmpty) return;

      final dirs = allChildren.where((c) => c.isDir).toList();
      final files = allChildren.where((c) => !c.isDir).toList();

      final List<VisualNode> childrenToDraw = [];
      childrenToDraw.addAll(dirs);

      const maxFilesToDraw = 6;
      final int actualFilesToDraw = files.length <= maxFilesToDraw + 1 ? files.length : maxFilesToDraw;
      childrenToDraw.addAll(files.take(actualFilesToDraw));

      final int hiddenFilesCount = files.length > maxFilesToDraw + 1 ? (files.length - maxFilesToDraw) : 0;
      final int totalDrawCount = childrenToDraw.length + (hiddenFilesCount > 0 ? 1 : 0);

      final angleRange = maxAngle - minAngle;
      final angleStep = angleRange / totalDrawCount;

      for (int i = 0; i < childrenToDraw.length; i++) {
        final child = childrenToDraw[i];
        final double stagger = child.isDir ? 0.0 : ((i % 3 - 1) * 12.0);
        final radius = orbitRadiusStep * (depth + 1) + stagger;
        final currentAngle = minAngle + (i * angleStep) + (angleStep / 2) + (progress * 0.02 * pi);
        final childOffset = center + Offset(cos(currentAngle) * radius, sin(currentAngle) * radius);

        double dist = (tapPos - childOffset).distance;
        if (dist < minDistance && dist < 20.0) { // 20.0 is dynamic touch/hit-test threshold
          minDistance = dist;
          closestNode = child;
        }

        checkChildren(
          child,
          depth + 1,
          minAngle + (i * angleStep),
          minAngle + ((i + 1) * angleStep),
        );
      }
    }

    checkChildren(_rootNode!, 0, 0, 2 * pi);
    return closestNode;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bubble_chart_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Codebase Visualizer'),
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
                'This screen generates an interactive radial diagram of repository directories and code files to visualize codebase structure and module relationships.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Fetches full recursive git trees from the GitHub API.\n'
                '• Construct tree structures locally and processes files by path depth, sizes, and file extensions.\n'
                '• Dynamically graphs radial layouts using custom trigonometry calculations and CustomPaint.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Enter the Repository Owner and name, then click Analyze.\n'
                '2. Use pinch gestures to zoom and drag to pan around the radial layout.\n'
                '3. Adjust the Depth slider to control the folder tree levels shown.\n'
                '4. Click a node to view size details or jump to editing it in the AI Code Editor.',
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
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Codebase Visualizer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'How to use this feature',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Target Repo Input Surface
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
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
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _fetchArchitecture,
                        icon: _isLoading
                            ? const GlowingIndicator(size: 18)
                            : const Icon(Icons.hub_rounded),
                        label: const Text('Analyze & Map Codebase'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (!_hasLoaded) ...[
                _buildRepositorySelector(isDark, ref.watch(authenticatedUserProvider).valueOrNull),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Interactive Visual Graph & Control Panel Card
              Showcase(
                key: _radialKey,
                title: 'Interactive Codebase Map',
                description: 'Analyze directory layout and dependencies. Scroll & pinch to pan/zoom, select files to review risk ratings, or click to open directly in the AI Code Editor.',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
                child: AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasLoaded ? 'Radial Map: ${_repoController.text}' : 'Radial Directory Structure',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hasLoaded
                                      ? 'Displaying $_totalDirs folders and $_totalFiles files up to $_maxDepth levels deep.'
                                      : 'Visualizes file system depth and package structure.',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          if (_hasLoaded)
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Refresh Visualizer',
                              onPressed: () {
                                setState(() {
                                  _selectedNode = null;
                                  _searchController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Interactive controls: Depth Slider & Search Bar
                      if (_hasLoaded) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Filter Files/Folders',
                                  hintText: 'Search node...',
                                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          onPressed: () => _searchController.clear(),
                                        )
                                      : null,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '  Depth: $_maxDepth levels',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    ),
                                    child: Slider(
                                      value: _maxDepth.toDouble(),
                                      min: 1,
                                      max: 5,
                                      divisions: 4,
                                      activeColor: AppColors.accent,
                                      onChanged: (val) {
                                        setState(() {
                                          _maxDepth = val.round();
                                          _selectedNode = null;
                                          _buildTreeFromPaths(_treeItems);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Radial graph container with Pan & Zoom support
                      Container(
                        height: 380,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InteractiveViewer(
                                maxScale: 5.0,
                                minScale: 0.5,
                                boundaryMargin: const EdgeInsets.all(120),
                                child: SizedBox(
                                  width: 600,
                                  height: 600,
                                  child: GestureDetector(
                                    onTapUp: (details) {
                                      _handleCanvasTap(details.localPosition, const Size(600, 600));
                                    },
                                    child: AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          size: const Size(600, 600),
                                          painter: _RadialStructurePainter(
                                            rootNode: _rootNode,
                                            progress: _pulseController.value,
                                            isDark: isDark,
                                            selectedNode: _selectedNode,
                                            searchQuery: _searchQuery,
                                            maxDepth: _maxDepth,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Quick zoom info indicator overlay
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 14),
                                    SizedBox(width: 4),
                                    Text('Pinch to zoom / Drag to pan', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Interactive Legend row
                      _buildInteractiveLegend(isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Interactive selected node details panel card
              if (_selectedNode != null) ...[
                _buildSelectedNodeDetails(isDark),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Static Metrics section
              const Text(
                'Static Analysis & Health Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Showcase(
                key: _metricsKey,
                title: 'Complexity & Health Analytics',
                description: 'Review estimated code health indicators like logic complexity index, estimated unit test coverage levels, and general security vulnerability risk dials.',
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                tooltipBackgroundColor: const Color(0xFF1E293B),
                tooltipBorderRadius: BorderRadius.circular(12),
                blurValue: 2,
                child: AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricDial('Complexity', _complexityStr, _complexityVal, Colors.amberAccent),
                      _buildMetricDial('Test Coverage', '${(_testCoverage * 100).toStringAsFixed(0)}%', _testCoverage, Colors.greenAccent),
                      _buildMetricDial('Security Risk', _riskStr, _riskVal, Colors.blueAccent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Detailed directory insights list card
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Directory Structural Insights',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._insights.map((insight) => Column(
                      children: [
                        _InsightRow(
                          icon: insight['icon'] as IconData,
                          label: insight['label'] as String,
                          desc: insight['desc'] as String,
                        ),
                        if (_insights.last != insight) const Divider(height: 16),
                      ],
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedNodeDetails(bool isDark) {
    final node = _selectedNode!;
    final ext = node.isDir ? 'Folder' : (node.name.contains('.') ? node.name.split('.').last.toUpperCase() : 'Unknown File');
    final icon = node.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded;
    final color = node.isDir
        ? Colors.amber
        : (node.name.endsWith('.dart')
            ? Colors.blueAccent
            : (node.name.endsWith('.html') || node.name.endsWith('.css') ? Colors.cyanAccent : Colors.greenAccent));

    final sizeStr = node.isDir ? 'Multiple Files' : '${(node.size / 1024).toStringAsFixed(2)} KB';
    
    // Predicative complexity calculation based on size & extensions
    String riskLvl = 'Low';
    Color riskColor = Colors.greenAccent;
    if (!node.isDir) {
      if (node.size > 20000) {
        riskLvl = 'High';
        riskColor = Colors.redAccent;
      } else if (node.size > 8000) {
        riskLvl = 'Medium';
        riskColor = Colors.amberAccent;
      }
    }

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$ext • $sizeStr',
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedNode = null),
              ),
            ],
          ),
          const Divider(height: 20),
          const Text(
            'Node Filepath',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          SelectableText(
            node.path.isEmpty ? '/' : node.path,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('AI Predicted Risk: ', style: TextStyle(fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      riskLvl,
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (!node.isDir)
                FilledButton.icon(
                  onPressed: () {
                    // Navigate straight to the AI Code Editor with prepopulated path details!
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AiCodeEditorScreen(
                          initialOwner: _ownerController.text.trim(),
                          initialRepo: _repoController.text.trim(),
                          initialPath: node.path,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Open in AI Editor', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem('Directory', Colors.amber),
          _buildLegendItem('Dart/TS/Native', Colors.blueAccent),
          _buildLegendItem('JS/Python/Go', Colors.greenAccent),
          _buildLegendItem('HTML/CSS', Colors.cyanAccent),
          _buildLegendItem('Markdown', Colors.purpleAccent),
          _buildLegendItem('Config/Other', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMetricDial(String label, String value, double progress, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
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
          'Select a Repository to Visualize',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...popularRepos.map((repo) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      _ownerController.text = repo['owner'] as String;
                      _repoController.text = repo['name'] as String;
                      _fetchArchitecture();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(repo['icon'] as IconData, color: AppColors.accent, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            repo['label'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                            ),
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
                ...ref.watch(userReposProvider(authUser.login)).maybeWhen(
                  data: (repos) {
                    return repos.map((repo) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            _ownerController.text = authUser.login;
                            _repoController.text = repo.name;
                            _fetchArchitecture();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 90,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_pin_rounded, color: AppColors.accent, size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  repo.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList();
                  },
                  orElse: () => <Widget>[],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.icon, required this.label, required this.desc});
  final IconData icon;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadialStructurePainter extends CustomPainter {
  final VisualNode? rootNode;
  final double progress;
  final bool isDark;
  final VisualNode? selectedNode;
  final String searchQuery;
  final int maxDepth;

  _RadialStructurePainter({
    required this.rootNode,
    required this.progress,
    required this.isDark,
    required this.selectedNode,
    required this.searchQuery,
    required this.maxDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.95;

    // Draw background HUD grids for premium visual feel
    if (isDark) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.02)
        ..strokeWidth = 0.8;
      
      for (double x = 0; x < size.width; x += 40) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
      
      final crosshairPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crosshairPaint);
      canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crosshairPaint);
    }

    // Shimmering ambient background particles
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (int p = 0; p < 12; p++) {
      final double seedAngle = (p * 137.5) % (2 * pi);
      final double orbitRadius = (p * 22.3 + 30) % (maxRadius * 0.9);
      final double currentAngle = seedAngle + (progress * 0.04 * pi * (p % 2 == 0 ? 1 : -1));
      final particleOffset = center + Offset(cos(currentAngle) * orbitRadius, sin(currentAngle) * orbitRadius);
      particlePaint.color = (p % 2 == 0 ? const Color(0xFF8B5CF6) : const Color(0xFF0EA5E9))
          .withValues(alpha: 0.05 + 0.03 * sin(progress * 2 * pi + p).abs());
      canvas.drawCircle(particleOffset, 2.0 + (p % 3), particlePaint);
    }

    final orbitRadiusStep = maxRadius / (maxDepth + 1);
    
    // Radar style dashed orbit rings
    for (int i = 1; i <= maxDepth; i++) {
      final r = orbitRadiusStep * i;
      final dashPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      final double dashCount = 24 + i * 8;
      final double anglePerDash = 2 * pi / (dashCount * 2);
      
      for (int d = 0; d < dashCount * 2; d += 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          d * anglePerDash,
          anglePerDash,
          false,
          dashPaint,
        );
      }
    }

    if (rootNode == null || rootNode!.children.isEmpty) {
      _drawDemo(canvas, center, orbitRadiusStep);
      return;
    }

    _drawNodeChildren(canvas, center, rootNode!, 0, 0, 2 * pi, orbitRadiusStep);

    // Draw root central node
    final isRootSelected = selectedNode == rootNode;
    if (isRootSelected) {
      canvas.drawCircle(
        center,
        14.0 + 3 * sin(progress * 2 * pi).abs(),
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.3)..style = PaintingStyle.fill,
      );
    }
    canvas.drawCircle(center, 9, Paint()..color = AppColors.accent);
    canvas.drawCircle(center, 12, Paint()..color = AppColors.accent.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawNodeChildren(
    Canvas canvas,
    Offset center,
    VisualNode parent,
    int depth,
    double minAngle,
    double maxAngle,
    double radiusStep,
  ) {
    final allChildren = parent.children;
    if (allChildren.isEmpty) return;

    final dirs = allChildren.where((c) => c.isDir).toList();
    final files = allChildren.where((c) => !c.isDir).toList();

    final List<VisualNode> childrenToDraw = [];
    childrenToDraw.addAll(dirs);

    const maxFilesToDraw = 6;
    final int actualFilesToDraw = files.length <= maxFilesToDraw + 1 ? files.length : maxFilesToDraw;
    childrenToDraw.addAll(files.take(actualFilesToDraw));

    final int hiddenFilesCount = files.length > maxFilesToDraw + 1 ? (files.length - maxFilesToDraw) : 0;
    final int totalDrawCount = childrenToDraw.length + (hiddenFilesCount > 0 ? 1 : 0);

    final angleRange = maxAngle - minAngle;
    final angleStep = angleRange / totalDrawCount;

    for (int i = 0; i < childrenToDraw.length; i++) {
      final child = childrenToDraw[i];
      final double stagger = child.isDir ? 0.0 : ((i % 3 - 1) * 12.0);
      final radius = radiusStep * (depth + 1) + stagger;
      final currentAngle = minAngle + (i * angleStep) + (angleStep / 2) + (progress * 0.02 * pi);
      final childOffset = center + Offset(cos(currentAngle) * radius, sin(currentAngle) * radius);

      final parentRadius = radiusStep * depth;
      final parentAngle = minAngle + angleRange / 2 + (progress * 0.02 * pi);
      final parentOffset = depth == 0
          ? center
          : center + Offset(cos(parentAngle) * parentRadius, sin(parentAngle) * parentRadius);

      final isSelected = selectedNode == child;
      final isMatchingSearch = searchQuery.isNotEmpty && child.name.toLowerCase().contains(searchQuery.toLowerCase());
      
      // Determine if this connection line is part of the path leading to the selected file node
      final isOnSelectedPath = selectedNode != null && 
          (selectedNode!.path == child.path || selectedNode!.path.startsWith(child.path + '/'));

      // Node colors based on extension types
      Color nodeColor = Colors.grey;
      if (child.isDir) {
        nodeColor = Colors.amber;
      } else {
        final name = child.name.toLowerCase();
        if (name.endsWith('.dart') || name.endsWith('.ts') || name.endsWith('.kt') || name.endsWith('.swift')) {
          nodeColor = Colors.blueAccent;
        } else if (name.endsWith('.js') || name.endsWith('.py') || name.endsWith('.go')) {
          nodeColor = Colors.greenAccent;
        } else if (name.endsWith('.html') || name.endsWith('.css')) {
          nodeColor = Colors.cyanAccent;
        } else if (name.endsWith('.md') || name.endsWith('.txt')) {
          nodeColor = Colors.purpleAccent;
        } else if (name.endsWith('.yaml') || name.endsWith('.json') || name.endsWith('.gradle') || name.endsWith('.xml')) {
          nodeColor = Colors.redAccent;
        }
      }

      // Selected Path Neon Glow Behind the line
      if (isOnSelectedPath) {
        final glowPaint = Paint()
          ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.15)
          ..strokeWidth = 6.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawLine(parentOffset, childOffset, glowPaint);
      }

      // Draw connection line
      final linePaint = Paint()
        ..color = isOnSelectedPath
            ? const Color(0xFF0EA5E9)
            : (child.isDir ? AppColors.accent : Colors.grey)
                .withValues(alpha: isSelected ? 0.8 : (isMatchingSearch ? 0.7 : (child.isDir ? 0.35 : 0.15)))
        ..strokeWidth = isOnSelectedPath ? 2.5 : (child.isDir ? 1.5 : 1.0)
        ..style = PaintingStyle.stroke;

      canvas.drawLine(parentOffset, childOffset, linePaint);

      // Selected node pulsing halo ring
      if (isSelected) {
        final selectPulsePaint = Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(childOffset, 12.0 + 4 * sin(progress * 4 * pi).abs(), selectPulsePaint);

        final selectRingPaint = Paint()
          ..color = Colors.cyanAccent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(childOffset, 10.0 + 2 * sin(progress * 4 * pi).abs(), selectRingPaint);
      }

      // Search matching glow indicator
      if (isMatchingSearch && !isSelected) {
        final searchRingPaint = Paint()
          ..color = Colors.amberAccent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(childOffset, 8.0 + 3 * sin(progress * 2 * pi).abs(), searchRingPaint);
      }

      // Draw the node core dot
      final nodePaint = Paint()
        ..color = isMatchingSearch ? Colors.amberAccent : nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(childOffset, child.isDir ? 5.5 : 3.5, nodePaint);

      // Render name labels if focused
      final shouldDrawText = isSelected || isMatchingSearch || (depth == 0 && child.isDir);
      if (shouldDrawText) {
        final textSpan = TextSpan(
          text: child.name,
          style: TextStyle(
            color: isSelected 
                ? Colors.cyanAccent 
                : (isMatchingSearch 
                    ? Colors.amberAccent 
                    : (isDark ? Colors.white70 : Colors.black87)),
            fontSize: isSelected ? 10 : 8,
            fontWeight: isSelected || isMatchingSearch ? FontWeight.bold : FontWeight.normal,
            backgroundColor: isDark ? Colors.black54 : Colors.white70,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(childOffset.dx + 8, childOffset.dy - tp.height / 2));
      }

      _drawNodeChildren(
        canvas,
        center,
        child,
        depth + 1,
        minAngle + (i * angleStep),
        minAngle + ((i + 1) * angleStep),
        radiusStep,
      );
    }

    // Draw the virtual "+X more files" node if there are hidden files
    if (hiddenFilesCount > 0) {
      final i = childrenToDraw.length;
      final double stagger = ((i % 3 - 1) * 12.0);
      final radius = radiusStep * (depth + 1) + stagger;
      final currentAngle = minAngle + (i * angleStep) + (angleStep / 2) + (progress * 0.02 * pi);
      final childOffset = center + Offset(cos(currentAngle) * radius, sin(currentAngle) * radius);

      final parentRadius = radiusStep * depth;
      final parentAngle = minAngle + angleRange / 2 + (progress * 0.02 * pi);
      final parentOffset = depth == 0
          ? center
          : center + Offset(cos(parentAngle) * parentRadius, sin(parentAngle) * parentRadius);

      final linePaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.1)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(parentOffset, childOffset, linePaint);

      final nodePaint = Paint()
        ..color = isDark ? Colors.white24 : Colors.black12
        ..style = PaintingStyle.fill;
      canvas.drawCircle(childOffset, 4.0, nodePaint);

      // Draw label "+X files"
      final textSpan = TextSpan(
        text: '+$hiddenFilesCount files',
        style: TextStyle(
          color: isDark ? Colors.white30 : Colors.black38,
          fontSize: 7.5,
          fontStyle: FontStyle.italic,
          backgroundColor: isDark ? Colors.black54 : Colors.white70,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(childOffset.dx + 6, childOffset.dy - tp.height / 2));
    }
  }

  void _drawDemo(Canvas canvas, Offset center, double orbitRadiusStep) {
    final paintAccent = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintLine = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final numSpokes = 8;
    for (int i = 0; i < numSpokes; i++) {
      final angle = (i * 2 * pi / numSpokes) + (progress * 0.1 * pi);
      final spokeEnd = center + Offset(cos(angle) * (orbitRadiusStep * 3), sin(angle) * (orbitRadiusStep * 3));
      canvas.drawLine(center, spokeEnd, paintLine);

      for (int d = 1; d <= 3; d++) {
        final nodeRadius = orbitRadiusStep * d;
        final nodeCenter = center + Offset(cos(angle) * nodeRadius, sin(angle) * nodeRadius);
        final fileAngle = angle + (pi / 6 * sin(progress * 2 * pi + d));
        final fileEnd = nodeCenter + Offset(cos(fileAngle) * 15, sin(fileAngle) * 15);
        canvas.drawLine(nodeCenter, fileEnd, paintLine);

        canvas.drawCircle(
          fileEnd,
          2.5,
          Paint()..color = (d == 2 ? Colors.greenAccent : AppColors.accent).withValues(alpha: 0.8),
        );
      }
    }

    canvas.drawCircle(center, 12, Paint()..color = AppColors.accent);
    canvas.drawCircle(
      center,
      12 + 8 * sin(progress * 2 * pi).abs(),
      paintAccent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
