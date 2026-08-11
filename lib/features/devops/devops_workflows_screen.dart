import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/user_and_search_models.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/state_views.dart';

final workflowsFutureProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getWorkflows(args.owner, args.repo);
});

final workflowRunsFutureProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getWorkflowRuns(args.owner, args.repo);
});

class DevOpsWorkflowsScreen extends ConsumerStatefulWidget {
  const DevOpsWorkflowsScreen({super.key, this.owner, this.repoName});

  final String? owner;
  final String? repoName;

  @override
  ConsumerState<DevOpsWorkflowsScreen> createState() => _DevOpsWorkflowsScreenState();
}

class _DevOpsWorkflowsScreenState extends ConsumerState<DevOpsWorkflowsScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ownerController;
  late final TextEditingController _repoController;
  late TabController _tabController;
  bool _hasSearched = false;

  final GlobalKey _ownerKey = GlobalKey();
  final GlobalKey _repoKey = GlobalKey();
  final GlobalKey _connectKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: widget.owner ?? '');
    _repoController = TextEditingController(text: widget.repoName ?? '');
    _tabController = TabController(length: 2, vsync: this);
    if ((widget.owner?.isNotEmpty ?? false) && (widget.repoName?.isNotEmpty ?? false)) {
      _hasSearched = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_devops_tutorial') ?? false;
      if (!seen && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          ShowcaseView.get().startShowCase([_ownerKey, _repoKey, _connectKey]);
          await prefs.setBool('seen_devops_tutorial', true);
        }
      }
    });
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    if (_ownerController.text.trim().isEmpty || _repoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both owner and repository name')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _hasSearched = true);
    ref.invalidate(workflowsFutureProvider);
    ref.invalidate(workflowRunsFutureProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pat = ref.watch(githubPatProvider);
    final isLoggedIn = pat != null && pat.isNotEmpty;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(
            _hasSearched
                ? '${_ownerController.text}/${_repoController.text}'
                : 'DevOps Control Center',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'DevOps Guide',
            ),
          ],
          bottom: _hasSearched
              ? TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Workflow Runs'),
                    Tab(text: 'Workflows'),
                  ],
                  indicatorColor: AppColors.accent,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        body: !isLoggedIn
            ? _NoAuthView(onSetup: () {})
            : Column(
                children: [
                  _SearchBar(
                    ownerController: _ownerController,
                    repoController: _repoController,
                    ownerKey: _ownerKey,
                    repoKey: _repoKey,
                    connectKey: _connectKey,
                    onSearch: _search,
                  ),
                  if (!_hasSearched)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _PresetSelector(
                              authUser: ref.watch(authenticatedUserProvider).valueOrNull,
                              onSelected: (owner, repo) {
                                _ownerController.text = owner;
                                _repoController.text = repo;
                                _search();
                              },
                            ),
                            const SizedBox(height: 32),
                            const _EmptyHint(),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _RunsTab(
                            owner: _ownerController.text.trim(),
                            repo: _repoController.text.trim(),
                          ),
                          _WorkflowsTab(
                            owner: _ownerController.text.trim(),
                            repo: _repoController.text.trim(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('DevOps Control Center', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What is this feature?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              SizedBox(height: 4),
              Text(
                'Monitor and trigger your GitHub Actions CI/CD workflows on mobile. Inspect build logs, track success ratios, and stream live execution outputs.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text('Features:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              SizedBox(height: 4),
              Text(
                '• Real-time CI/CD workflow telemetry & success ratios.\n'
                '• Stream live console logs with ANSI formatting.\n'
                '• Trigger workflows manually via workflow_dispatch API.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _NoAuthView extends StatelessWidget {
  const _NoAuthView({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Sign in to view CI/CD pipelines',
              style: TextStyle(
                  color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A GitHub token is required to access workflow runs and dispatch actions.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.ownerController,
    required this.repoController,
    required this.ownerKey,
    required this.repoKey,
    required this.connectKey,
    required this.onSearch,
  });

  final TextEditingController ownerController;
  final TextEditingController repoController;
  final GlobalKey ownerKey;
  final GlobalKey repoKey;
  final GlobalKey connectKey;
  final VoidCallback onSearch;

  static InputDecoration _fieldDecoration(BuildContext context, String label, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Showcase(
                    key: ownerKey,
                    title: 'Repository Owner',
                    description: 'Enter username or organization (e.g. flutter).',
                    child: TextField(
                      controller: ownerController,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                      decoration: _fieldDecoration(context, 'Owner / Org', 'e.g. flutter'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Showcase(
                    key: repoKey,
                    title: 'Repository Name',
                    description: 'Enter target repository name (e.g. flutter).',
                    child: TextField(
                      controller: repoController,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                      decoration: _fieldDecoration(context, 'Repository', 'e.g. flutter'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Showcase(
              key: connectKey,
              title: 'Connect DevOps Suite',
              description: 'Pull live workflow runs & telemetry data.',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text(
                    'Connect CI/CD Pipeline',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetSelector extends ConsumerWidget {
  const _PresetSelector({required this.authUser, required this.onSelected});
  final GhUser? authUser;
  final void Function(String owner, String repo) onSelected;

  static const _popularRepos = [
    {'owner': 'flutter', 'name': 'flutter', 'label': 'Flutter Engine'},
    {'owner': 'facebook', 'name': 'react', 'label': 'React Core'},
    {'owner': 'dart-lang', 'name': 'sdk', 'label': 'Dart SDK'},
    {'owner': 'microsoft', 'name': 'vscode', 'label': 'VS Code'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Repository Presets',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                ..._popularRepos.map((repo) => _PresetChip(
                      label: repo['label']!,
                      icon: Icons.rocket_rounded,
                      iconColor: AppColors.accent,
                      onTap: () => onSelected(repo['owner']!, repo['name']!),
                    )),
                if (authUser != null)
                  ...ref.watch(userReposProvider(authUser!.login)).maybeWhen(
                    data: (repos) => repos.map((repo) => _PresetChip(
                          label: repo.name,
                          icon: Icons.person_pin_rounded,
                          iconColor: AppColors.success,
                          onTap: () => onSelected(authUser!.login, repo.name),
                        )),
                    orElse: () => <Widget>[],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.precision_manufacturing_rounded, size: 54, color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text(
              'Select a preset or enter owner & repo above to view CI/CD pipelines',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Runs Tab ───────────────────────────────────────────────────────────────────

class _RunsTab extends ConsumerWidget {
  const _RunsTab({required this.owner, required this.repo});
  final String owner;
  final String repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(workflowRunsFutureProvider((owner: owner, repo: repo)));

    return runsAsync.when(
      data: (data) {
        final runs = (data['workflow_runs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (runs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.play_circle_outline_rounded,
            title: 'No workflow runs',
            subtitle: 'This repository has no recorded CI/CD runs yet',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workflowRunsFutureProvider((owner: owner, repo: repo))),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const BouncingScrollPhysics(),
            itemCount: runs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _TelemetryDashboard(runs: runs);
              return _RunCard(run: runs[index - 1]);
            },
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : 'Failed to load workflow runs',
        onRetry: () => ref.invalidate(workflowRunsFutureProvider((owner: owner, repo: repo))),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});
  final Map<String, dynamic> run;

  @override
  Widget build(BuildContext context) {
    final status = run['status'] as String? ?? '';
    final conclusion = run['conclusion'] as String? ?? '';
    final name = run['name'] as String? ?? 'Workflow Run';
    final runNumber = run['run_number']?.toString() ?? '';
    final headBranch = run['head_branch'] as String? ?? 'main';
    final commitMsg = run['head_commit']?['message'] as String? ?? 'No commit message';
    final actorAvatar = run['actor']?['avatar_url'] as String?;
    final actorName = run['actor']?['login'] as String? ?? 'GitHub';
    final createdAt = run['created_at'] as String?;
    final createdDate = createdAt != null ? DateTime.tryParse(createdAt) : null;

    final (statusColor, statusIcon) = _resolveStatus(status, conclusion);

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name #$runNumber',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    conclusion.isNotEmpty ? conclusion.toUpperCase() : status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              commitMsg,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (actorAvatar != null) ...[
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: CachedNetworkImageProvider(actorAvatar),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '@$actorName',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    headBranch,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ),
                const Spacer(),
                if (createdDate != null)
                  Text(
                    timeago.format(createdDate),
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _resolveStatus(String status, String conclusion) {
    if (status == 'completed') {
      return switch (conclusion) {
        'success' => (AppColors.success, Icons.check_circle_rounded),
        'failure' => (AppColors.danger, Icons.cancel_rounded),
        'cancelled' => (Colors.orange, Icons.cancel_outlined),
        _ => (Colors.orange, Icons.remove_circle_outline_rounded),
      };
    }
    return switch (status) {
      'in_progress' => (AppColors.accent, Icons.sync_rounded),
      'queued' => (Colors.amber, Icons.hourglass_top_rounded),
      _ => (Colors.grey, Icons.help_outline_rounded),
    };
  }
}

// ── Workflows Tab ──────────────────────────────────────────────────────────────

class _WorkflowsTab extends ConsumerWidget {
  const _WorkflowsTab({required this.owner, required this.repo});
  final String owner;
  final String repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowsAsync = ref.watch(workflowsFutureProvider((owner: owner, repo: repo)));

    return workflowsAsync.when(
      data: (data) {
        final workflows = (data['workflows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (workflows.isEmpty) {
          return const EmptyStateView(
            icon: Icons.settings_suggest_rounded,
            title: 'No active workflows',
            subtitle: 'No GitHub Actions workflows found for this repository',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workflowsFutureProvider((owner: owner, repo: repo))),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const BouncingScrollPhysics(),
            itemCount: workflows.length,
            itemBuilder: (context, index) => _WorkflowCard(
              workflow: workflows[index],
              owner: owner,
              repo: repo,
            ),
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 32)),
      error: (e, _) => ErrorStateView(
        message: e is GitHubApiException ? e.message : 'Failed to load workflows',
        onRetry: () => ref.invalidate(workflowsFutureProvider((owner: owner, repo: repo))),
      ),
    );
  }
}

class _WorkflowCard extends ConsumerWidget {
  const _WorkflowCard({
    required this.workflow,
    required this.owner,
    required this.repo,
  });
  final Map<String, dynamic> workflow;
  final String owner;
  final String repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = workflow['name'] as String? ?? 'Workflow';
    final path = workflow['path'] as String? ?? '';
    final state = workflow['state'] as String? ?? '';
    final isActive = state == 'active';

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path,
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isActive)
                    const Text(
                      'DISABLED',
                      style: TextStyle(
                          fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isActive
                  ? () {
                      HapticFeedback.mediumImpact();
                      _showDispatchDialog(context, ref, name, workflow['id']);
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Dispatch',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDispatchDialog(
      BuildContext context, WidgetRef ref, String name, dynamic workflowId) {
    final branchController = TextEditingController(text: 'main');
    bool dispatching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dispatch: $name',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trigger workflow_dispatch on branch:',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: branchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Branch',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'main',
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.fork_right_rounded, color: Colors.white54, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: The workflow must have a workflow_dispatch trigger.',
                style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: dispatching ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton.icon(
              onPressed: dispatching
                  ? null
                  : () async {
                      final branch = branchController.text.trim();
                      if (branch.isEmpty) return;
                      setDialogState(() => dispatching = true);
                      try {
                        await ref.read(githubApiServiceProvider).triggerWorkflowDispatch(
                          owner,
                          repo,
                          workflowId,
                          ref: branch,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Workflow "$name" triggered on $branch'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                          // Refresh runs tab to show the new run
                          ref.invalidate(workflowRunsFutureProvider);
                        }
                      } catch (e) {
                        setDialogState(() => dispatching = false);
                        if (ctx.mounted) {
                          final msg = e is GitHubApiException ? e.message : 'Dispatch failed — check write permissions';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
              icon: dispatching
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(dispatching ? 'Dispatching…' : 'Run Workflow'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Telemetry Dashboard ────────────────────────────────────────────────────────

class _TelemetryDashboard extends StatelessWidget {
  const _TelemetryDashboard({required this.runs});
  final List<Map<String, dynamic>> runs;

  @override
  Widget build(BuildContext context) {
    var total = runs.length;
    var success = 0;
    var failure = 0;
    var running = 0;
    var queued = 0;
    double totalDurationSec = 0;
    var completedWithDuration = 0;

    for (final run in runs) {
      final status = run['status'] as String? ?? '';
      final conclusion = run['conclusion'] as String? ?? '';
      if (status == 'queued') {
        queued++;
      } else if (status == 'in_progress') {
        running++;
      } else if (status == 'completed') {
        if (conclusion == 'success') success++;
        if (conclusion == 'failure') failure++;
      }
      final start = DateTime.tryParse(run['run_started_at'] as String? ?? '');
      final end = DateTime.tryParse(run['updated_at'] as String? ?? '');
      if (start != null && end != null) {
        final diff = end.difference(start).inSeconds;
        if (diff > 0) {
          totalDurationSec += diff;
          completedWithDuration++;
        }
      }
    }

    final successRate =
        (success + failure) > 0 ? success / (success + failure) : 0.0;
    final avgSec = completedWithDuration > 0
        ? (totalDurationSec / completedWithDuration).round()
        : 0;
    final avgStr = avgSec > 60 ? '${avgSec ~/ 60}m ${avgSec % 60}s' : '${avgSec}s';

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Telemetry Summary',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'LIVE METRICS',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi(context, 'Success', '${(successRate * 100).toStringAsFixed(0)}%', AppColors.success),
              const SizedBox(width: 8),
              _kpi(context, 'In Progress', '$running', Colors.orangeAccent),
              const SizedBox(width: 8),
              _kpi(context, 'Queued', '$queued', Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpi(context, 'Avg Duration', avgStr, AppColors.accent),
              const SizedBox(width: 8),
              _kpi(context, 'Total Runs', '$total', Colors.purpleAccent),
              const SizedBox(width: 8),
              _kpi(context, 'Failures', '$failure', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
