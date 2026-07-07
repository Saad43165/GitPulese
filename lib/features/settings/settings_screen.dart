import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/search_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../auth/auth_dialog.dart';
import '../tracked_repos/tracked_repos_screen.dart';
import '../user_detail/user_detail_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import 'widgets_configuration_screen.dart';
import '../../widgets/github_analytics_section.dart';
import '../repo_detail/ai_pr_review_screen.dart';
import '../devops/devops_workflows_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final pat = ref.watch(githubPatProvider);
    final hasPat = pat != null && pat.isNotEmpty;
    final backgroundEnabled = ref.watch(backgroundChecksEnabledProvider);
    final defaultTab = ref.watch(defaultSearchTabProvider);
    final compactCards = ref.watch(compactCardsProvider);
    final authUser = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafePage(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.lg),
          physics: const BouncingScrollPhysics(),
          children: [
            const PageHeader(
              title: 'Settings',
              subtitle: 'Configure accounts, premium AI tools, preferences, and data options',
            ),
            const SizedBox(height: AppSpacing.md),

            // SECTION 1: ACCOUNT & CORE INTEGRATIONS
            _buildSectionHeader(context, 'Account & Integration'),
            const SizedBox(height: AppSpacing.xs),
            if (hasPat)
              authUser.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _SignedInErrorCard(onSignOut: () {
                  ref.read(githubPatProvider.notifier).save(null);
                }),
                data: (user) {
                  if (user == null) {
                    return _SignedInErrorCard(onSignOut: () {
                      ref.read(githubPatProvider.notifier).save(null);
                    });
                  }
                  return _ProfileCard(user: user, isDark: isDark, ref: ref, context: context);
                },
              )
            else
              _buildConnectCard(context),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 2: AI & FLAGSHIP DEV FEATURES
            _buildSectionHeader(context, 'AI & DevOps Suite'),
            const SizedBox(height: AppSpacing.xs),
            _buildSectionCard(
              context,
              children: [
                _buildListTile(
                  context,
                  icon: Icons.rate_review_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'AI Pull Request Reviewer',
                  subtitle: 'Audit PR links for bugs, security, and fixes',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiPrReviewScreen()),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.rocket_launch_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'DevOps Control Center',
                  subtitle: 'Trigger manual workflows and monitor build run logs',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DevOpsWorkflowsScreen()),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.widgets_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Configure Home Widgets',
                  subtitle: 'Preview, customize, and add GitPulse widgets',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WidgetsConfigurationScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 3: APP PREFERENCES
            _buildSectionHeader(context, 'App Customization'),
            const SizedBox(height: AppSpacing.xs),
            _buildSectionCard(
              context,
              children: [
                _buildThemeSelector(context, ref, themeMode),
                _buildDivider(isDark),
                _buildSwitchTile(
                  context,
                  icon: Icons.view_agenda_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Compact Cards Layout',
                  subtitle: 'Denser listing style for code repositories',
                  value: compactCards,
                  onChanged: (v) => ref.read(compactCardsProvider.notifier).setCompact(v),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.tab_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Default Search Tab',
                  subtitle: 'Set to: ${defaultTab.name.toUpperCase()}',
                  onTap: () => _showDefaultTabPicker(context, ref, defaultTab),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 4: NOTIFICATIONS & ARCHIVE
            _buildSectionHeader(context, 'Alerts & Archives'),
            const SizedBox(height: AppSpacing.xs),
            _buildSectionCard(
              context,
              children: [
                _buildSwitchTile(
                  context,
                  icon: Icons.sync_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Background Release Checks',
                  subtitle: 'Check tracked repos in background for new releases',
                  value: backgroundEnabled,
                  onChanged: (v) => ref.read(backgroundCheckTogglerProvider).setEnabled(v),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Tracked Repositories',
                  subtitle: 'Manage repositories you get release notifications for',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrackedReposScreen()),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.bookmark_border_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  title: 'Saved Repositories',
                  subtitle: 'View your bookmarked repositories archive',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 5: DATA, SYSTEM & TUTORIALS
            _buildSectionHeader(context, 'System & Privacy'),
            const SizedBox(height: AppSpacing.xs),
            _buildSectionCard(
              context,
              children: [
                _buildListTile(
                  context,
                  icon: Icons.refresh_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Reset User Guides',
                  subtitle: 'Re-trigger interactive guides and tutorials on next use',
                  onTap: () => _confirmResetGuides(context),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.cleaning_services_rounded,
                  iconColor: Colors.orange,
                  title: 'Clear Application Cache',
                  subtitle: 'Remove cached images and data files to free space',
                  onTap: () => _clearCache(context),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.history_rounded,
                  iconColor: AppColors.danger,
                  title: 'Clear Search History',
                  subtitle: 'Permanently remove search and viewed item history',
                  onTap: () => _confirmClearHistory(context, ref),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.bookmark_remove_outlined,
                  iconColor: AppColors.danger,
                  title: 'Clear Saved Repositories',
                  subtitle: 'Permanently remove all bookmarks',
                  onTap: () => _confirmClearBookmarks(context, ref),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 6: INFO & ABOUT
            _buildSectionHeader(context, 'About GitPulse'),
            const SizedBox(height: AppSpacing.xs),
            _buildSectionCard(
              context,
              children: [
                _buildListTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.grey,
                  title: 'GitPulse Info',
                  subtitle: 'Version 1.0.0 · Developed by Saad Ikram',
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.green,
                  title: 'Privacy & Security Policy',
                  subtitle: 'Stated local-first storage and PAT guidelines',
                  onTap: () => _showPrivacySheet(context),
                ),
                _buildDivider(isDark),
                _buildListTile(
                  context,
                  icon: Icons.api_outlined,
                  iconColor: Colors.teal,
                  title: 'GitHub API Documentation',
                  subtitle: 'View official GitHub API resources',
                  onTap: () => launchUrl(
                    Uri.parse('https://docs.github.com/en/rest'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
            ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ThemeMode current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget buildThemeTab(ThemeMode mode, String label, IconData icon) {
      final selected = current == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(themeModeProvider.notifier).setMode(mode);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected 
                ? (isDark ? const Color(0xFF2D3748) : Colors.white)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected && !isDark ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon, 
                  size: 16, 
                  color: selected ? AppColors.accent : (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3))
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: selected 
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.brightness_medium_rounded, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose dark, light, or system settings',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 180,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                buildThemeTab(ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                buildThemeTab(ThemeMode.light, 'Light', Icons.light_mode_rounded),
                buildThemeTab(ThemeMode.system, 'Auto', Icons.brightness_auto_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('assets/images/github.png', color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect GitHub Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Unlock stars, follows & more',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _BenefitRow(icon: Icons.star_rounded, text: 'Star repositories with one tap', color: Color(0xFFF59E0B)),
          const SizedBox(height: 8),
          const _BenefitRow(icon: Icons.people_rounded, text: 'Follow & unfollow developers', color: AppColors.accent),
          const SizedBox(height: 8),
          const _BenefitRow(icon: Icons.speed_rounded, text: 'Higher API rate limits (5000/hr)', color: Color(0xFF10B981)),
          const SizedBox(height: 8),
          const _BenefitRow(icon: Icons.person_rounded, text: 'View your own full profile', color: Color(0xFF3B82F6)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AuthDialog(),
              ),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Sign In with GitHub'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(SearchTab tab) => switch (tab) {
        SearchTab.repositories => 'Repositories',
        SearchTab.code => 'Code',
        SearchTab.users => 'Users',
        SearchTab.issues => 'Issues',
      };

  IconData _tabIcon(SearchTab tab) => switch (tab) {
        SearchTab.repositories => Icons.folder_outlined,
        SearchTab.code => Icons.code_rounded,
        SearchTab.users => Icons.person_outline_rounded,
        SearchTab.issues => Icons.bug_report_outlined,
      };

  void _showDefaultTabPicker(BuildContext context, WidgetRef ref, SearchTab current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Default search tab',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              ...SearchTab.values.map((tab) {
                final selected = tab == current;
                return ListTile(
                  leading: Icon(_tabIcon(tab)),
                  title: Text(_tabLabel(tab)),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(defaultSearchTabProvider.notifier).setTab(tab);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('App cache cleared successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear cache.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('This removes every search and viewed item from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(historyActionsProvider).clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmClearBookmarks(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all saved repos?'),
        content: const Text('This removes every bookmarked repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              ref.read(bookmarkActionsProvider).clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved repos cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmResetGuides(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset User Guides?'),
        content: const Text('This will reset all onboarding tutorials and walkthroughs so you can view them again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('seen_search_tutorial');
              await prefs.remove('seen_repo_detail_tutorial');
              await prefs.remove('seen_user_detail_tutorial');
              await prefs.remove('seen_pr_review_tutorial');
              await prefs.remove('seen_devops_tutorial');
              await prefs.remove('seen_discovery_swipe');
              await prefs.remove('seen_arena_tutorial');
              await prefs.remove('seen_ai_explain');
              await prefs.remove('seen_ai_editor_tutorial');
              await prefs.remove('seen_architecture_tutorial');
              await prefs.remove('seen_portfolio_tutorial');
              await prefs.remove('seen_vault_tutorial');
              await prefs.remove('completed_onboarding');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Onboarding & User Guides have been reset! Restart the app to see the onboarding carousel again.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicator handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.greenAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Privacy & Security',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'How GitPulse safeguards your experience',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildPrivacyItem(
                      isDark: isDark,
                      icon: Icons.dns_rounded,
                      color: Colors.blueAccent,
                      title: 'Local Storage Guarantee',
                      subtitle:
                          'Your activity history, repository bookmarks, and downloaded workspace caches are saved locally on your device in a secure SQLite database. We do not store or mirror your code on external servers.',
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyItem(
                      isDark: isDark,
                      icon: Icons.vpn_key_rounded,
                      color: Colors.amberAccent,
                      title: 'Direct Client-Side Auth',
                      subtitle:
                          'Your GitHub Personal Access Token (PAT) is stored directly inside secure device memory. Credentials are only transmitted directly to api.github.com. We operate under a strict zero-knowledge model.',
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyItem(
                      isDark: isDark,
                      icon: Icons.psychology_alt_rounded,
                      color: Colors.purpleAccent,
                      title: 'Secure AI Pipelines',
                      subtitle:
                          'AI operations (e.g. PR reviews, diagnostics) run on secure endpoints. Code fragments are transmitted ephemerally solely for processing, and are never saved or trained on.',
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyItem(
                      isDark: isDark,
                      icon: Icons.visibility_off_rounded,
                      color: Colors.tealAccent,
                      title: 'No Telemetry or Tracking',
                      subtitle:
                          'GitPulse contains zero third-party advertisement libraries, telemetry tracking, or analytic scripts. We believe developer tools should be clean, focused, and secure.',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Footer / CTA
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'I Understand & Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.isDark,
    required this.ref,
    required this.context,
  });
  final dynamic user;
  final bool isDark;
  final WidgetRef ref;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user.avatarUrl as String,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name ?? user.login,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.login}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (user.bio != null && (user.bio as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.bio as String,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _StatBadge(label: 'Followers', value: user.followers as int),
              const SizedBox(width: 8),
              _StatBadge(label: 'Following', value: (user.following as int) + ref.watch(followingDeltaProvider)),
              const SizedBox(width: 8),
              _StatBadge(label: 'Repos', value: user.publicRepos as int),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          ref.watch(userReposProvider(user.login as String)).maybeWhen(
                data: (repos) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GitHubAnalyticsSection(repos: repos, compact: true),
                ),
                orElse: () => const SizedBox.shrink(),
              ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(username: user.login as String),
                    ),
                  ),
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('View Profile'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(githubPatProvider.notifier).save(null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInErrorCard extends ConsumerWidget {
  const _SignedInErrorCard({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Could not load profile. Connection issue or token is invalid.'),
          ),
          TextButton(
            onPressed: () => ref.invalidate(authenticatedUserProvider),
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: onSignOut,
            child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
