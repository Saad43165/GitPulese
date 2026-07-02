import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/search_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../tracked_repos/tracked_repos_screen.dart';

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
            _SettingsGroup(
              title: 'GitHub Access',
              children: [
                AppSurface(
                  onTap: () => _showPatDialog(context, ref),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: _SettingsIcon(icon: Icons.key_outlined),
                    title: const Text('Personal Access Token'),
                    subtitle: Text(
                      hasPat
                          ? 'Token saved — higher API limits active'
                          : 'Optional — increases rate limits from 60 to 5,000/hr',
                    ),
                    trailing: Icon(
                      hasPat ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                      color: hasPat ? AppColors.success : null,
                    ),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
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
            ),
            _SettingsGroup(
              title: 'Search',
              children: [
                AppSurface(
                  onTap: () => _showDefaultTabPicker(context, ref, defaultTab),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: _SettingsIcon(icon: Icons.tab_outlined),
                    title: const Text('Default search tab'),
                    subtitle: Text(_tabLabel(defaultTab)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Notifications',
              children: [
                AppSurface(
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
            ),
            _SettingsGroup(
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
              ],
            ),
            _SettingsGroup(
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
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
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