import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../compare/compare_screen.dart';
import '../devops/devops_workflows_screen.dart';
import '../editor/ai_code_editor_screen.dart';
import '../architecture/architecture_visualizer_screen.dart';
import '../portfolio/portfolio_generator_screen.dart';
import '../vault/offline_codebase_vault_screen.dart';
import '../repo_detail/ai_pr_review_screen.dart';

class DeveloperHelpHubScreen extends ConsumerStatefulWidget {
  const DeveloperHelpHubScreen({super.key});

  @override
  ConsumerState<DeveloperHelpHubScreen> createState() => _DeveloperHelpHubScreenState();
}

class _DeveloperHelpHubScreenState extends ConsumerState<DeveloperHelpHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  int? _expandedIndex;

  // Selected goal in the interactive wizard
  String? _selectedGoal;

  final List<Map<String, dynamic>> _features = [
    {
      'title': 'AI PR Reviewer',
      'category': 'AI Tools',
      'icon': Icons.rate_review_rounded,
      'gradient': [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      'summary': 'Automated pull request code review and security auditing.',
      'description': 'Audits Pull Requests for bugs, security holes, and code improvements. It fetches git diff files, parses change sets, and uses LLM agents to provide targeted, constructive feedback.',
      'techStack': ['GitHub PR API', 'Git Diff Parser', 'Groq Llama 3 API', 'Custom Diff Chunking'],
      'flow': ['PR Created', 'Diff Chunks Extracted', 'LLM Security Audit', 'Interactive Review UI'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiPrReviewScreen()),
        );
      }
    },
    {
      'title': 'DevOps Control Center',
      'category': 'DevOps',
      'icon': Icons.rocket_launch_rounded,
      'gradient': [Color(0xFF0EA5E9), Color(0xFF0284C7)],
      'summary': 'GitHub Actions workflow monitor and manual pipeline dispatcher.',
      'description': 'Tracks workflow runs, execution durations, average success metrics, and live-streams build console logs with interactive regex keyword search. Includes manual workflow dispatching.',
      'techStack': ['GitHub Actions API', 'ANSI Console Parser', 'fl_chart', 'Workflow Dispatch Trigger'],
      'flow': ['Poll Runs API', 'Live Log Streaming', 'ANSI Code Mapping', 'Manual Pipeline Dispatch'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DevOpsWorkflowsScreen()),
        );
      }
    },
    {
      'title': 'AI Code Editor',
      'category': 'AI Tools',
      'icon': Icons.code_rounded,
      'gradient': [Color(0xFF10B981), Color(0xFF059669)],
      'summary': 'Interactive AI editor for repository file modifications.',
      'description': 'Refactor code files, request architectural adjustments, and commit patches directly back to your branch using embedded generative models.',
      'techStack': ['GitHub Contents API', 'Groq Coding Assistant', 'Unified Diff Generator', 'Git Commit Service'],
      'flow': ['Read Source File', 'AI Prompt Analysis', 'Generate Patch / Diff', 'Commit & Push Changes'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiCodeEditorScreen()),
        );
      }
    },
    {
      'title': 'Codebase Visualizer',
      'category': 'Visualization',
      'icon': Icons.bubble_chart_rounded,
      'gradient': [Color(0xFFF59E0B), Color(0xFFD97706)],
      'summary': 'Radial directory and class dependency visualizer.',
      'description': 'Extracts codebase structural definitions. Renders interactive dependency maps, file nesting paths, and complexity metrics to simplify navigating unfamiliar projects.',
      'techStack': ['Local/Remote AST Extractor', 'Custom Graph Layout Engine', 'Dart Parser AST Library', 'Directory Tree Mapper'],
      'flow': ['Scan Repository Files', 'Extract Imports & Classes', 'Build Graph Nodes', 'Interactive Tree Render'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ArchitectureVisualizerScreen()),
        );
      }
    },
    {
      'title': 'Portfolio Generator',
      'category': 'Utilities',
      'icon': Icons.art_track_rounded,
      'gradient': [Color(0xFFEC4899), Color(0xFFDB2777)],
      'summary': 'One-click developer portfolio and profile builder.',
      'description': 'Mines developer activity, repository profiles, contribution timelines, and language weightings. Compiles a high-impact responsive static site layout ready to deploy.',
      'techStack': ['GitHub Stats Engine', 'SVG Badge Generator', 'Static Markdown Templates', 'Vercel Deployment webhook'],
      'flow': ['Gather Profile Stats', 'Pin Top Repositories', 'Generate Site Template', 'Export Portfolio Bundle'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PortfolioGeneratorScreen()),
        );
      }
    },
    {
      'title': 'Offline Code Vault',
      'category': 'Utilities',
      'icon': Icons.offline_pin_rounded,
      'gradient': [Color(0xFF6366F1), Color(0xFF4F46E5)],
      'summary': 'Offline codebase indexer and syntax highlighted viewer.',
      'description': 'Downloads codebases as compressed archives, indexes directories locally, and offers regex offline search capability alongside an offline syntax viewer.',
      'techStack': ['Zip Archive Extractor', 'Local File Storage API', 'Local Search Tokenizer', 'Offline Code Highlight CSS'],
      'flow': ['Download Zip Package', 'Extract to Application Storage', 'Tokenize & Index Content', 'Offline Regex Code Search'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OfflineCodebaseVaultScreen()),
        );
      }
    },
    {
      'title': 'Repository Compare',
      'category': 'Utilities',
      'icon': Icons.sports_martial_arts_rounded,
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'summary': 'Side-by-side framework and repository comparison engine.',
      'description': 'Contrasts release velocity, star milestones, issue ratios, and language shares between any two target repositories to help evaluate project dependencies.',
      'techStack': ['GitHub Repository API', 'Release History Scraper', 'Comparative Progress Graphs', 'Language Metric Parser'],
      'flow': ['Fetch Repo A & B Details', 'Aggregate Stars / Issues', 'Format Release Frequency', 'Render Comparison Cards'],
      'onTap': (BuildContext context) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CompareScreen()),
        );
      }
    }
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    // Filter features
    final filteredFeatures = _features.where((f) {
      final matchesSearch = f['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['summary'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['techStack'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || f['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return SafePage(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: const Text('Developer Help Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to GitPulse Suite',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discover what each tool does under the hood and how they fit into your engineering workflow.',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),

            // Interactive Playground / Goal Wizard
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'What is your target goal today?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildGoalChips(),
                      if (_selectedGoal != null) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildGoalSuggestionCard(isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Search & Category Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search features, APIs, or stack integrations...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCategoryFilters(isDark),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Catalog list
            filteredFeatures.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No features found matching your search.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final f = filteredFeatures[index];
                          final isExpanded = _expandedIndex == index;
                          return _buildCatalogItem(f, index, isExpanded, isDark, primaryTextColor, secondaryTextColor);
                        },
                        childCount: filteredFeatures.length,
                      ),
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalChips() {
    final List<Map<String, String>> goals = [
      {'id': 'portfolio', 'label': '🚀 Build profile site'},
      {'id': 'review', 'label': '🛡️ Audit Pull Request'},
      {'id': 'pipeline', 'label': '⚙️ Track test logs'},
      {'id': 'map', 'label': '🗺️ Explore code hierarchy'},
      {'id': 'edit', 'label': '📝 Quick refactor file'},
      {'id': 'offline', 'label': '💾 Work offline'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: goals.map((goal) {
        final selected = _selectedGoal == goal['id'];
        return ChoiceChip(
          label: Text(
            goal['label']!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: selected,
          onSelected: (val) {
            setState(() {
              _selectedGoal = val ? goal['id'] : null;
            });
          },
          selectedColor: AppColors.accent.withValues(alpha: 0.25),
          checkmarkColor: AppColors.accent,
        );
      }).toList(),
    );
  }

  Widget _buildGoalSuggestionCard(bool isDark) {
    Map<String, dynamic>? recommendedFeature;
    String suggestionText = '';

    switch (_selectedGoal) {
      case 'portfolio':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'Portfolio Generator');
        suggestionText = 'Use the Portfolio Generator to automatically build and customize your markdown profile or deploy static sites representing your commits and repositories.';
        break;
      case 'review':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'AI PR Reviewer');
        suggestionText = 'Hook your branch modifications through the AI PR Reviewer to audit codebase additions for bugs, security holes, and code formatting suggestions.';
        break;
      case 'pipeline':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'DevOps Control Center');
        suggestionText = 'Monitor build sequences, review Average success metrics, read ANSI logging consoles, and execute workflow runs manually.';
        break;
      case 'map':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'Codebase Visualizer');
        suggestionText = 'Select Codebase Visualizer to view radial import layouts, directory sizes, dependency graphs, and code metrics.';
        break;
      case 'edit':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'AI Code Editor');
        suggestionText = 'Edit codebase file paths directly, request refactors from embedded coding models, and generate commit logs.';
        break;
      case 'offline':
        recommendedFeature = _features.firstWhere((element) => element['title'] == 'Offline Code Vault');
        suggestionText = 'Download files as compressed packages to index and explore code with custom local regex lookups even when offline.';
        break;
    }

    if (recommendedFeature == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: recommendedFeature['gradient']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(recommendedFeature['icon'], color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended: ${recommendedFeature['title']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestionText,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => recommendedFeature!['onTap'](context),
              icon: const Icon(Icons.rocket_launch_rounded, size: 14),
              label: const Text('Open Feature Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(bool isDark) {
    final List<String> categories = ['All', 'AI Tools', 'DevOps', 'Visualization', 'Utilities'];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final selected = _selectedCategory == cat;
          return ChoiceChip(
            label: Text(
              cat,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: selected,
            onSelected: (val) {
              setState(() {
                _selectedCategory = val ? cat : 'All';
              });
            },
            selectedColor: isDark ? Colors.white12 : Colors.black12,
          );
        },
      ),
    );
  }

  Widget _buildCatalogItem(
    Map<String, dynamic> f,
    int index,
    bool isExpanded,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppColors.accent.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with Icon, Title, Expand indicator
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: f['gradient'],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(f['icon'], color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f['category'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    f['summary'],
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),

                  // Expanded Section
                  if (isExpanded) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Technical Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f['description'],
                      style: TextStyle(fontSize: 12, height: 1.4, color: primaryTextColor),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Under the Hood Pipeline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    _buildPipelineFlow(f['flow'], isDark),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Technologies Used',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _buildTechChips(f['techStack']),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => f['onTap'](context),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Launch Screen', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineFlow(List<dynamic> flow, bool isDark) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: flow.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_right_alt_rounded, color: AppColors.accent.withValues(alpha: 0.5), size: 20),
        ),
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              flow[index],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTechChips(List<dynamic> techs) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: techs.map<Widget>((tech) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tech,
            style: const TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
