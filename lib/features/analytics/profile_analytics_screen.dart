import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/github_analytics_section.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../../widgets/page_header.dart';
import '../../widgets/glowing_indicator.dart';
import '../../providers/ai_providers.dart';
class ProfileAnalyticsScreen extends ConsumerStatefulWidget {
  const ProfileAnalyticsScreen({super.key});

  @override
  ConsumerState<ProfileAnalyticsScreen> createState() => _ProfileAnalyticsScreenState();
}

class _ProfileAnalyticsScreenState extends ConsumerState<ProfileAnalyticsScreen> {
  final TextEditingController _patController = TextEditingController();
  bool _isSaving = false;
  int _activeTab = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  @override
  void dispose() {
    _patController.dispose();
    super.dispose();
  }

  void _savePat(String val) async {
    if (val.trim().isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(githubPatProvider.notifier).save(val.trim());
    if (mounted) {
      setState(() => _isSaving = false);
      _patController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal Access Token saved successfully!')),
      );
    }
  }

  void _disconnect() async {
    HapticFeedback.vibrate();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Account'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        content: const Text('Are you sure you want to disconnect and clear your Personal Access Token?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(githubPatProvider.notifier).save(null);
      ref.read(demoUsernameProvider.notifier).state = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected successfully.')),
        );
      }
    }
  }



  Map<String, String> _compileArchetype(List<GhRepo> repos) {
    if (repos.isEmpty) {
      return {
        'title': 'The Code Novice',
        'desc': 'No public repositories found yet. Start building to unlock your developer archetype.',
        'archetype': 'Explorer',
      };
    }

    final Map<String, int> langCounts = {};
    for (final r in repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';

    switch (topLang.toLowerCase()) {
      case 'dart':
        return {
          'title': 'The Flutter Alchemist',
          'desc': 'You weave stunning UI layouts and seamless multiplatform systems in your sleep. Dart is your weapon of choice, and cross-platform synergy is your design creed.',
          'archetype': 'Frontend & UI',
        };
      case 'python':
        return {
          'title': 'The Data Mystic',
          'desc': 'From machine learning weights to quick automation scripts, Python is your canvas. You turn raw data streams into analytical gold and automated pipelines.',
          'archetype': 'Data Science & AI',
        };
      case 'javascript':
      case 'typescript':
        return {
          'title': 'The Web Weaver',
          'desc': 'The browser is your sandbox. You build high-speed interactive user interfaces, orchestrate component rendering, and live in the asynchronous async-await cosmos.',
          'archetype': 'Web Stack',
        };
      case 'rust':
      case 'go':
        return {
          'title': 'The Metal Sage',
          'desc': 'Concurrency, safety, and raw compiler optimization are your passion. You build lightweight, bulletproof microservices and low-level binaries that run at peak memory safety.',
          'archetype': 'Systems & Backend',
        };
      case 'c++':
      case 'c':
        return {
          'title': 'The Core Engine',
          'desc': 'You speak directly to the hardware. Pointer arithmetic and memory allocation don\'t scare you—you build performance-critical native engines that power the world.',
          'archetype': 'Low-level Core',
        };
      default:
        return {
          'title': 'The Versatile Voyager',
          'desc': 'You don\'t bind yourself to a single syntax. You adapt quickly, pick the best tool for the job, and navigate multiple ecosystems with ease.',
          'archetype': 'Polyglot Core',
        };
    }
  }

  Future<void> _shareCard(GhUser user, String topLang) async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture(pixelRatio: 3.0);
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/${user.login}_wrapped.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Check out my Elite Developer Profile card on GitPulse! 🚀🔥',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share card: $e')),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      reserveBottomNav: true,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Profile Analytics',
              subtitle: 'Your GitHub stats and profile insights',
              showBackButton: false,
            ),
            Expanded(
              child: userAsync.when(
                data: (user) {
                  if (user == null) {
                    return _buildSetupScreen(isDark);
                  }
                  return _buildAnalyticsContent(user, isDark);
                },
                loading: () => const Center(child: GlowingIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                        const SizedBox(height: 16),
                        Text('Failed to load profile: $e', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(authenticatedUserProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupScreen(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.analytics_outlined,
            size: 80,
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          Text(
            'Personal Analytics Hub',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect your GitHub account using a Personal Access Token (PAT) to view your developer statistics, contributions, languages, and custom profiles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          AppSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configure Personal Access Token',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your token is encrypted and stored locally on your device only.',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _patController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'GitHub PAT (classic or fine-grained)',
                    hintText: 'ghp_...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _isSaving
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: GlowingIndicator(size: 16),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: () => _savePat(_patController.text),
                          ),
                  ),
                  onSubmitted: _savePat,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR EXPLORE DEMO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black45,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(demoUsernameProvider.notifier).state = 'Saad43165';
            },
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('View Demo Profile (Saad43165)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(GhUser user, bool isDark) {
    return Consumer(
      builder: (context, ref, child) {
        final reposAsync = ref.watch(userReposProvider(user.login));
        return reposAsync.when(
          data: (repos) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimalist Identity Strip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 1.5),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name ?? user.login,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${user.login}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.logout_rounded, size: 14, color: AppColors.danger),
                        label: const Text('Disconnect', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ),

                // Pill segmented navigation control
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(0, 'Overview', Icons.dashboard_customize_rounded),
                      _buildTabButton(1, 'Archetype', Icons.psychology_rounded),
                      _buildTabButton(2, 'Dev Card', Icons.style_rounded),
                    ],
                  ),
                ),

                // Stack preserving scroll layouts
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      // TAB 0: OVERVIEW & CHARTS
                      RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(userReposProvider(user.login));
                          ref.invalidate(authenticatedUserProvider);
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppSurface(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMiniStat(user.publicRepos.toString(), 'Repositories'),
                                    _buildMiniStat(
                                      (user.followers + ref.watch(userFollowProvider(user.login).notifier).followersDelta).clamp(0, double.maxFinite).toInt().toString(),
                                      'Followers',
                                    ),
                                    _buildMiniStat(
                                      (user.following + ref.watch(followDeltaMapProvider).values.fold(0, (a, b) => a + b)).clamp(0, double.maxFinite).toInt().toString(),
                                      'Following',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              GitHubAnalyticsSection(repos: repos),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),

                      // TAB 1: ARCHETYPE ANALYSIS
                      _buildArchetypeTab(user, repos, isDark),

                      // TAB 2: ELITE CARD EMBED
                      _buildCardTab(user, repos, isDark),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: GlowingIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading user repositories: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(userReposProvider(user.login)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.accent : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.accent)
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchetypeTab(GhUser user, List<GhRepo> repos, bool isDark) {
    final archetypeData = _compileArchetype(repos);
    final totalSize = repos.fold<int>(0, (sum, r) => sum + r.size);
    final avgSize = repos.isEmpty ? 0 : totalSize / repos.length;
    final totalStars = repos.fold<int>(0, (sum, repo) => sum + repo.stargazersCount);

    final langCounts = <String, int>{};
    for (final r in repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';
    final langColor = AppColors.colorForLanguage(topLang);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  langColor.withValues(alpha: 0.15),
                  isDark ? const Color(0xFF1E293B) : Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: langColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: langColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: langColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: langColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  archetypeData['title']!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: langColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    archetypeData['archetype']!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: langColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  archetypeData['desc']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Magical Developer Telemetry',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          AppSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInsightRow(
                  icon: Icons.snippet_folder_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  label: 'Average Repository Size',
                  value: () {
                    if (repos.isEmpty) return '0 KB';
                    final avgMb = avgSize / 1024;
                    return avgMb < 1
                        ? '${avgSize.toStringAsFixed(0)} KB'
                        : '${avgMb.toStringAsFixed(1)} MB';
                  }(),
                  description: 'Indicates lightweight, optimized code bases and modular packages.',
                ),
                const Divider(height: 24),
                _buildInsightRow(
                  icon: Icons.star_border_purple500_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Star Influence Factor',
                  value: repos.isEmpty ? '0.0 ★' : '${(totalStars / repos.length).toStringAsFixed(1)} ★',
                  description: 'The average star power ratings for your public hubs.',
                ),
                const Divider(height: 24),
                _buildInsightRow(
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Developer Velocity',
                  value: '${repos.length} Codebases',
                  description: 'Total number of active public software hubs maintained.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Language Orbit Composition',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          AppSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (sortedLangs.isEmpty)
                  const Text('No language telemetry available.', style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ...sortedLangs.map((entry) {
                    final percentage = (entry.value / repos.length) * 100;
                    final color = AppColors.colorForLanguage(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}% of repos',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: isDark ? Colors.white10 : Colors.black12,
                              color: color,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildCardTab(GhUser user, List<GhRepo> repos, bool isDark) {
    final langCounts = <String, int>{};
    for (final r in repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            Screenshot(
              controller: _screenshotController,
              child: _buildEliteCard(user, repos, isDark),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 320,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSharing ? null : () => _shareCard(user, topLang),
                icon: _isSharing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share Developer Card', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEliteCard(GhUser user, List<GhRepo> repos, bool isDark) {
    int totalStars = repos.fold(0, (sum, repo) => sum + repo.stargazersCount);
    final langCounts = <String, int>{};
    for (final r in repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';

    return Container(
      width: 320,
      height: 480,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.colorForLanguage(topLang).withValues(alpha: 0.3),
            const Color(0xFF0F172A),
            const Color(0xFF1E1B4B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 15),
          )
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Opacity(
                opacity: 0.12,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: SweepGradient(
                      colors: [Colors.purple, Colors.blue, Colors.green, Colors.yellow, Colors.red, Colors.purple],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.colorForLanguage(topLang), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ELITE DEV',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.colorForLanguage(topLang),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LVL ${math.min(99, (totalStars / 50).ceil() + (user.followers / 20).ceil())}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.colorForLanguage(topLang), Colors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.5),
                        blurRadius: 20,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  user.name ?? user.login,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${user.login} • $topLang Master',
                  style: TextStyle(
                    color: AppColors.colorForLanguage(topLang),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCardMiniStat(formatCount(totalStars), 'STARS', Icons.star_rounded),
                      _buildCardMiniStat(formatCount(user.followers), 'FANS', Icons.people_alt_rounded),
                      _buildCardMiniStat('${user.publicRepos}', 'REPOS', Icons.folder_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hub_rounded, color: Colors.white54, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'GITPULSE SYSTEM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMiniStat(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: Colors.white70),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
