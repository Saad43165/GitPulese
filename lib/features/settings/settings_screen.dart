import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafePage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            const PageHeader(
              title: 'Settings',
              subtitle: 'Appearance, search, data, and notifications',
            ),
            const _GitHubAccessGroup(),
            const _AppearanceGroup(),
            const _HomeWidgetConfigGroup(),
            const _SearchGroup(),
            const _NotificationsGroup(),
            const _DataGroup(),
            const _AboutGroup(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _GitHubAccessGroup extends ConsumerWidget {
  const _GitHubAccessGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pat = ref.watch(githubPatProvider);
    final hasPat = pat != null && pat.isNotEmpty;
    final authUser = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SettingsGroup(
      title: 'GitHub Account',
      children: [
        if (hasPat)
          // ── Signed-in profile card ──────────────────────────────────────
          authUser.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _SignedInErrorCard(onSignOut: () {
              ref.read(githubPatProvider.notifier).save(null);
            }),
            data: (user) {
              if (user == null) return _SignedInErrorCard(onSignOut: () {
                ref.read(githubPatProvider.notifier).save(null);
              });
              return _ProfileCard(user: user, isDark: isDark, ref: ref, context: context);
            },
          )
        else
          // ── Not signed in — connect card ────────────────────────────────
          AppSurface(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset('assets/images/github.png', color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect GitHub',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Unlock stars, follows & more',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BenefitRow(icon: Icons.star_rounded, text: 'Star repositories with one tap', color: const Color(0xFFF59E0B)),
                const SizedBox(height: 8),
                _BenefitRow(icon: Icons.people_rounded, text: 'Follow & unfollow developers', color: AppColors.accent),
                const SizedBox(height: 8),
                _BenefitRow(icon: Icons.speed_rounded, text: 'Higher API rate limits (5000/hr)', color: const Color(0xFF10B981)),
                const SizedBox(height: 8),
                _BenefitRow(icon: Icons.person_rounded, text: 'View your own full profile', color: const Color(0xFF3B82F6)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AuthDialog(),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign In with GitHub'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
                      style: TextStyle(
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

class _SignedInErrorCard extends StatelessWidget {
  const _SignedInErrorCard({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Could not load profile. Token may be invalid.'),
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


class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final compactCards = ref.watch(compactCardsProvider);
    return _SettingsGroup(
      title: 'Appearance',
      children: [
        AppSurface(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              _ThemeTile(
                title: 'Dark',
                subtitle: 'Easy on the eyes',
                icon: Icons.dark_mode_outlined,
                selected: themeMode == ThemeMode.dark,
                onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
              ),
              const Divider(height: 1),
              _ThemeTile(
                title: 'Light',
                subtitle: 'Clean and bright',
                icon: Icons.light_mode_outlined,
                selected: themeMode == ThemeMode.light,
                onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
              ),
              const Divider(height: 1),
              _ThemeTile(
                title: 'System',
                subtitle: 'Match device setting',
                icon: Icons.brightness_auto_outlined,
                selected: themeMode == ThemeMode.system,
                onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.system),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSurface(
          child: SwitchListTile(
            secondary: _SettingsIcon(icon: Icons.view_agenda_outlined),
            title: const Text('Compact cards'),
            subtitle: const Text('Denser layout for repository lists'),
            value: compactCards,
            onChanged: (v) => ref.read(compactCardsProvider.notifier).setCompact(v),
          ),
        ),
      ],
    );
  }
}

class _HomeWidgetConfigGroup extends StatelessWidget {
  const _HomeWidgetConfigGroup();

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'Home Screen Widgets',
      children: [
        AppSurface(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WidgetsConfigurationScreen()),
            );
          },
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.widgets_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Configure Home Widgets'),
            subtitle: const Text('View and install GitPulse widgets'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _SearchGroup extends ConsumerWidget {
  const _SearchGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTab = ref.watch(defaultSearchTabProvider);
    return _SettingsGroup(
      title: 'Search',
      children: [
        AppSurface(
          onTap: () => _showDefaultTabPicker(context, ref, defaultTab),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.tab_outlined),
            title: const Text('Default search tab'),
            subtitle: Text(defaultTab.name.toUpperCase()),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _NotificationsGroup extends ConsumerWidget {
  const _NotificationsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundEnabled = ref.watch(backgroundChecksEnabledProvider);
    return _SettingsGroup(
      title: 'Notifications',
      children: [
        AppSurface(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            secondary: _SettingsIcon(icon: Icons.sync_outlined),
            title: const Text('Background release checks'),
            subtitle: const Text('Periodically check tracked repos for new releases'),
            value: backgroundEnabled,
            onChanged: (v) => ref.read(backgroundCheckTogglerProvider).setEnabled(v),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSurface(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TrackedReposScreen()),
          ),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.notifications_active_outlined),
            title: const Text('Tracked repositories'),
            subtitle: const Text('Manage repos you receive alerts for'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _PersonalGroup extends StatelessWidget {
  const _PersonalGroup();

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'Personal',
      children: [
        AppSurface(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            );
          },
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.bookmark_border_rounded, color: AppColors.accent),
            title: const Text('Saved Repositories'),
            subtitle: const Text('View your bookmarked open-source projects'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _DataGroup extends ConsumerWidget {
  const _DataGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsGroup(
      title: 'Data',
      children: [
        AppSurface(
          onTap: () => _confirmClearHistory(context, ref),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.history_rounded, color: AppColors.danger),
            title: const Text('Clear history'),
            subtitle: const Text('Remove all search and view history'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSurface(
          onTap: () => _confirmClearBookmarks(context, ref),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.bookmark_remove_outlined, color: AppColors.danger),
            title: const Text('Clear saved repos'),
            subtitle: const Text('Remove all bookmarked repositories'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSurface(
          onTap: () => _clearCache(context),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _SettingsIcon(icon: Icons.cleaning_services_rounded, color: AppColors.warning),
            title: const Text('Clear App Cache'),
            subtitle: const Text('Free up storage used by images and data'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _AboutGroup extends StatelessWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'About',
      children: [
        AppSurface(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              ListTile(
                leading: _SettingsIcon(icon: Icons.info_outline_rounded),
                title: const Text('GitPulse'),
                subtitle: const Text('v1.0.0 · Developed by Saad Ikram'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: _SettingsIcon(icon: Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                subtitle: const Text('Data stays on your device. PAT is stored locally only.'),
                onTap: () => _showPrivacySheet(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: _SettingsIcon(icon: Icons.api_outlined),
                title: const Text('Powered by GitHub API'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(
                  Uri.parse('https://docs.github.com/en/rest'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

  String _tabLabel(SearchTab tab) => switch (tab) {
        SearchTab.repositories => 'Repositories',
        SearchTab.code => 'Code',
        SearchTab.users => 'Users',
        SearchTab.issues => 'Issues',
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

  IconData _tabIcon(SearchTab tab) => switch (tab) {
        SearchTab.repositories => Icons.folder_outlined,
        SearchTab.code => Icons.code_rounded,
        SearchTab.users => Icons.person_outline_rounded,
        SearchTab.issues => Icons.bug_report_outlined,
      };

  void _showPatDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final hasExisting = ref.read(githubPatProvider) != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Personal Access Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optional. Stored only on this device and sent directly to GitHub. '
              'Create a token with no scopes for read-only public data.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: hasExisting ? 'Enter new token to replace' : 'ghp_…',
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          if (hasExisting)
            TextButton(
              onPressed: () async {
                await ref.read(githubPatProvider.notifier).save(null);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token removed')),
                  );
                }
              },
              child: Text('Remove', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isEmpty) return;
              await ref.read(githubPatProvider.notifier).save(token);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
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
          SnackBar(
            content: const Text('Failed to clear cache.'),
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

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your privacy',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '• History and bookmarks are stored locally on your device.\n'
                '• Your GitHub token never leaves your phone except to api.github.com.\n'
                '• We do not collect analytics or personal data.\n'
                '• AI summaries use an optional cloud service when available.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _SettingsIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.outline),
    );
  }
}
