import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/repo_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../widgets/glowing_indicator.dart';
import '../repo_detail/repo_detail_screen.dart';

final discoveryFeedProvider = FutureProvider.autoDispose<List<GhRepo>>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  // Fetch trending/popular repos for the discovery feed
  // Using a query that guarantees high quality results
  final result = await api.searchRepositories(
    query: 'stars:>5000',
  );
  final items = List<GhRepo>.from(result.items);
  items.shuffle(); // Shuffle for a random "feed" experience
  return items;
});

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoveryFeedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: feedAsync.when(
        data: (repos) {
          if (repos.isEmpty) {
            return const Center(child: Text('No repositories found for discovery.'));
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(discoveryFeedProvider);
                  // Optional delay for UX
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: Scrollbar(
                  controller: _pageController,
                  thickness: 6,
                  radius: const Radius.circular(10),
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: repos.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      HapticFeedback.selectionClick();
                    },
                    itemBuilder: (context, index) {
                      final repo = repos[index];
                      return _DiscoveryCard(repo: repo);
                    },
                  ),
                ),
              ),
              // Swipe Guide
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      const Icon(Icons.keyboard_double_arrow_up_rounded, color: AppColors.accent, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        'SWIPE UP',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Refresh Button (Top Right)
              Positioned(
                top: 48,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Feed',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white54,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(discoveryFeedProvider);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlowingIndicator(),
              SizedBox(height: 16),
              Text('Curating your feed...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('Failed to load feed: $e')),
      ),
    );
  }
}

class _DiscoveryCard extends ConsumerWidget {
  const _DiscoveryCard({required this.repo});
  final GhRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = ref.watch(bookmarksProvider).when(
          data: (items) => items.any((r) => r['repoId'] == repo.id),
          loading: () => false,
          error: (_, __) => false,
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 48, 16, 110), // leave space for navbar and guide
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background gradient effect based on avatar
            Positioned(
              top: -50,
              right: -50,
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: repo.owner.avatarUrl,
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: repo.owner.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.owner.login,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              repo.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Tags row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (repo.language != null)
                        _buildTag(Icons.code_rounded, repo.language!, AppColors.accent),
                      _buildTag(Icons.star_rounded, formatCount(repo.stargazersCount), const Color(0xFFF59E0B)),
                      _buildTag(Icons.favorite_rounded, 'Health: ${repo.healthScore}', AppColors.success),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repo.description ?? 'No description provided.',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.fork_right_rounded, color: AppColors.accent, size: 20),
                                  const SizedBox(height: 4),
                                  Text(formatCount(repo.forksCount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Text('Forks', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.visibility_rounded, color: AppColors.success, size: 20),
                                  const SizedBox(height: 4),
                                  Text(formatCount(repo.watchersCount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Text('Watchers', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 20),
                                  const SizedBox(height: 4),
                                  Text(formatCount(repo.openIssuesCount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Text('Issues', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        label: isBookmarked ? 'Saved' : 'Save',
                        color: isBookmarked ? AppColors.accent : (isDark ? Colors.white : Colors.black),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(bookmarkActionsProvider).toggle(repo);
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'View Repo',
                        color: AppColors.success,
                        isPrimary: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RepoDetailScreen(owner: repo.owner.login, repoName: repo.name),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPrimary ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
