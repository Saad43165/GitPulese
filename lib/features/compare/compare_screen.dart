import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/repo_model.dart';
import '../../providers/ai_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/glowing_indicator.dart';

final _localSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final _localSearchResultsProvider = FutureProvider.autoDispose<List<GhRepo>>((ref) async {
  final query = ref.watch(_localSearchQueryProvider);
  if (query.trim().length < 2) return [];
  
  // Debounce API calls
  await Future.delayed(const Duration(milliseconds: 500));

  final api = ref.watch(githubApiServiceProvider);
  try {
    final result = await api.searchRepositories(query: query);
    return result.items;
  } catch (_) {
    return [];
  }
});

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repos = ref.watch(compareListProvider);
    final searchQuery = ref.watch(_localSearchQueryProvider);
    final searchResultsAsync = ref.watch(_localSearchResultsProvider);
    final aiState = ref.watch(compareAiProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define colors for the slots/bars to map visually
    final repoColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF9333EA), // Purple
      const Color(0xFFF59E0B), // Amber
    ];

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('AI Repo Arena'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (repos.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  ref.read(compareListProvider.notifier).clear();
                  ref.read(compareAiProvider.notifier).reset();
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear Arena'),
              ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // Dismiss search focus on tapping background
            _searchFocusNode.unfocus();
          },
          child: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    // Intro
                    Text(
                      'Decide between packages, frameworks, or libraries with real-time stats and AI analysis.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // The 3 Arena Slots
                    Row(
                      children: List.generate(3, (index) {
                        final hasRepo = index < repos.length;
                        final repoColor = repoColors[index % repoColors.length];

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 6,
                              right: index == 2 ? 0 : 6,
                            ),
                            child: AspectRatio(
                              aspectRatio: 0.95,
                              child: hasRepo
                                  ? _buildFilledSlot(repos[index], repoColor)
                                  : _buildEmptySlot(isDark),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        ref.read(_localSearchQueryProvider.notifier).state = val;
                      },
                      decoration: InputDecoration(
                        hintText: 'Search GitHub repos to add...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(_localSearchQueryProvider.notifier).state = '';
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Intelligent Search Suggestions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'org:', 'user:', 'language:', 'stars:>'
                        ].map((prefix) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              label: Text(
                                prefix,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide.none,
                              onPressed: () {
                                final text = _searchController.text;
                                _searchController.text = '$text $prefix'.trimLeft();
                                _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
                                ref.read(_localSearchQueryProvider.notifier).state = _searchController.text;
                                _searchFocusNode.requestFocus();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Comparison Dashboard & AI section
                    if (repos.length >= 2) ...[
                      // AI Battle Verdict trigger button
                      aiState.when(
                        data: (verdict) {
                          if (verdict != null) return const SizedBox.shrink();
                          return Center(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(compareAiProvider.notifier).runComparison(repos);
                                },
                                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                                label: const Text('Generate AI Battle Verdict', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // AI Analysis Results Panel
                      aiState.when(
                        data: (verdict) {
                          if (verdict == null) return const SizedBox.shrink();
                          return _buildAiVerdictPanel(verdict, isDark);
                        },
                        loading: () => _buildAiLoadingPanel(isDark),
                        error: (e, _) => _buildAiErrorPanel(e.toString()),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Visual Metrics Showdown Title
                      Text(
                        'Metrics Showdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Side-by-side metric charts
                      _buildMetricArena(
                        title: 'Stars',
                        icon: Icons.star_rounded,
                        repos: repos,
                        repoColors: repoColors,
                        valueExtractor: (r) => r.stargazersCount.toDouble(),
                        valueFormatter: (val) => formatCount(val.toInt()),
                      ),
                      _buildMetricArena(
                        title: 'Forks',
                        icon: Icons.call_split_rounded,
                        repos: repos,
                        repoColors: repoColors,
                        valueExtractor: (r) => r.forksCount.toDouble(),
                        valueFormatter: (val) => formatCount(val.toInt()),
                      ),
                      _buildMetricArena(
                        title: 'Health Score',
                        icon: Icons.favorite_rounded,
                        repos: repos,
                        repoColors: repoColors,
                        valueExtractor: (r) => r.healthScore.toDouble(),
                        valueFormatter: (val) => '${val.toInt()}/100',
                      ),
                      _buildMetricArena(
                        title: 'Open Issues',
                        icon: Icons.error_outline_rounded,
                        repos: repos,
                        repoColors: repoColors,
                        valueExtractor: (r) => r.openIssuesCount.toDouble(),
                        valueFormatter: (val) => formatCount(val.toInt()),
                        lowerIsBetter: true,
                      ),
                      const SizedBox(height: 100),
                    ] else ...[
                      // Arena onboarding state
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              size: 64,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Arena is Empty',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add at least 2 repositories to compare them.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),

                // Floating Search Results Overlay
                if (searchQuery.isNotEmpty)
                  Positioned(
                    left: AppSpacing.pageHorizontal,
                    right: AppSpacing.pageHorizontal,
                    top: 245, // approximate location below search bar
                    bottom: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: searchResultsAsync.when(
                          data: (results) {
                            if (results.isEmpty) {
                              return const Center(
                                child: Text('No repositories found'),
                              );
                            }
                            return ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              itemBuilder: (context, i) {
                                final repo = results[i];
                                final alreadyAdded = repos.any((r) => r.id == repo.id);

                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: repo.owner.avatarUrl,
                                      width: 32,
                                      height: 32,
                                    ),
                                  ),
                                  title: Text(
                                    repo.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    repo.owner.login,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      alreadyAdded
                                          ? Icons.check_circle_rounded
                                          : Icons.add_circle_outline_rounded,
                                      color: alreadyAdded
                                          ? AppColors.success
                                          : AppColors.accent,
                                    ),
                                    onPressed: alreadyAdded || repos.length >= 3
                                        ? null
                                        : () {
                                            ref.read(compareListProvider.notifier).add(repo);
                                            // Reset search
                                            _searchController.clear();
                                            ref.read(_localSearchQueryProvider.notifier).state = '';
                                            _searchFocusNode.unfocus();
                                          },
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: GlowingIndicator(),
                          ),
                          error: (e, _) => Center(
                            child: Text('Search failed: $e'),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilledSlot(GhRepo repo, Color accentColor) {
    return AppSurface(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: repo.owner.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                repo.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                repo.language ?? 'Mixed',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                ref.read(compareListProvider.notifier).remove(repo.id);
                ref.read(compareAiProvider.notifier).reset();
              },
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          style: BorderStyle.none, // simple border
        ),
      ),
      child: Center(
        child: Icon(
          Icons.add_rounded,
          color: isDark ? Colors.white38 : Colors.black38,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMetricArena({
    required String title,
    required IconData icon,
    required List<GhRepo> repos,
    required List<Color> repoColors,
    required double Function(GhRepo) valueExtractor,
    required String Function(double) valueFormatter,
    bool lowerIsBetter = false,
  }) {
    final values = repos.map(valueExtractor).toList();
    final double total = values.fold(0.0, (sum, val) => sum + val);

    // Identify the winner
    int? winningIndex;
    if (repos.length >= 2) {
      double bestVal = values.first;
      winningIndex = 0;
      for (int i = 1; i < values.length; i++) {
        if (lowerIsBetter) {
          if (values[i] < bestVal) {
            bestVal = values[i];
            winningIndex = i;
          }
        } else {
          if (values[i] > bestVal) {
            bestVal = values[i];
            winningIndex = i;
          }
        }
      }
    }

    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side-by-side segment bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: List.generate(repos.length, (i) {
                  final proportion = total == 0 ? 0.0 : values[i] / total;
                  final repoColor = repoColors[i % repoColors.length];

                  return Expanded(
                    flex: (proportion * 1000).toInt(),
                    child: Container(
                      height: 8,
                      color: repoColor,
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 12),

          // Values list
          Column(
            children: List.generate(repos.length, (i) {
              final repoColor = repoColors[i % repoColors.length];
              final isWinner = i == winningIndex;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: repoColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          repos[i].name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          valueFormatter(values[i]),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isWinner ? FontWeight.w900 : FontWeight.normal,
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.emoji_events_rounded, size: 12, color: Colors.amber),
                        ]
                      ],
                    ),
                  ],
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildAiVerdictPanel(String verdict, bool isDark) {
    return AppSurface(
      showAccentStripe: true,
      accentColor: AppColors.accent,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('AI Battle Verdict', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: verdict,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
              h1: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              listBullet: const TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiLoadingPanel(bool isDark) {
    return const AppSurface(
      margin: EdgeInsets.only(bottom: AppSpacing.lg),
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            GlowingIndicator(),
            SizedBox(height: 12),
            Text(
              'Analyzing stats and verdicts...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiErrorPanel(String error) {
    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Failed to run comparison: $error',
          style: const TextStyle(color: AppColors.danger, fontSize: 12),
        ),
      ),
    );
  }
}
