import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';
import '../auth/auth_dialog.dart';

final workflowsFutureProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return await api.getWorkflows(args.owner, args.repo);
});

final workflowRunsFutureProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({String owner, String repo})>((ref, args) async {
  final api = ref.watch(githubApiServiceProvider);
  return await api.getWorkflowRuns(args.owner, args.repo);
});

class DevOpsWorkflowsScreen extends ConsumerStatefulWidget {
  const DevOpsWorkflowsScreen({
    super.key,
    this.owner,
    this.repoName,
  });

  final String? owner;
  final String? repoName;

  @override
  ConsumerState<DevOpsWorkflowsScreen> createState() => _DevOpsWorkflowsScreenState();
}

class _DevOpsWorkflowsScreenState extends ConsumerState<DevOpsWorkflowsScreen> with SingleTickerProviderStateMixin {
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
    if (widget.owner != null && widget.repoName != null) {
      _hasSearched = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_devops_tutorial') ?? false;
      if (!seen && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          ShowcaseView.get().startShowCase([
            _ownerKey,
            _repoKey,
            _connectKey,
          ]);
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
    if (_ownerController.text.trim().isEmpty || _repoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both owner and repository name')),
      );
      return;
    }
    setState(() {
      _hasSearched = true;
    });
    ref.invalidate(workflowsFutureProvider);
    ref.invalidate(workflowRunsFutureProvider);
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('DevOps Control Center'),
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
                'This screen lets you monitor and run your GitHub Actions workflows directly. You can inspect pipeline runs, see Avg success durations, and review execution trend indicators.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Uses GitHub Actions API to stream runs and jobs.\n'
                '• Streams console logs using custom ANSI formatting engines.\n'
                '• Triggers workflows manually via the workflow_dispatch trigger API.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Enter the Repository Owner/Org name & Repository name.\n'
                '2. Click "Connect DevOps Suite".\n'
                '3. View list of runs or click the Play icon under "Workflows" to run a pipeline.',
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
      useAurora: true,
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: const AppBackButton(),
            title: const Text('DevOps Control Center'),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () => _showHelpDialog(context),
                tooltip: 'How to use this feature',
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
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                  )
                : null,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useColumn = constraints.maxWidth < 450;
                          final ownerField = Showcase(
                            key: _ownerKey,
                            title: 'Repository Owner / Organization',
                            description: 'Enter the GitHub username or organization name that owns the target repository (e.g., "flutter").',
                            titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            tooltipBackgroundColor: const Color(0xFF1E293B),
                            tooltipBorderRadius: BorderRadius.circular(12),
                            blurValue: 2,
                            child: TextField(
                              controller: _ownerController,
                              decoration: const InputDecoration(
                                labelText: 'Owner / Org',
                                hintText: 'e.g. flutter',
                                prefixIcon: Icon(Icons.business_rounded),
                              ),
                            ),
                          );

                          final repoField = Showcase(
                            key: _repoKey,
                            title: 'Repository Name',
                            description: 'Enter the specific name of the repository you want to integrate (e.g., "flutter").',
                            titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            tooltipBackgroundColor: const Color(0xFF1E293B),
                            tooltipBorderRadius: BorderRadius.circular(12),
                            blurValue: 2,
                            child: TextField(
                              controller: _repoController,
                              decoration: const InputDecoration(
                                labelText: 'Repository',
                                hintText: 'e.g. flutter',
                                prefixIcon: Icon(Icons.code_rounded),
                              ),
                            ),
                          );

                          if (useColumn) {
                            return Column(
                              children: [
                                ownerField,
                                const SizedBox(height: AppSpacing.sm),
                                repoField,
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: ownerField),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: repoField),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Showcase(
                        key: _connectKey,
                        title: 'Connect DevOps Suite',
                        description: 'Establish connection to pull live workflow lists, manual pipeline trigger states, and telemetry data.',
                        titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                        tooltipBackgroundColor: const Color(0xFF1E293B),
                        tooltipBorderRadius: BorderRadius.circular(12),
                        blurValue: 2,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _search,
                            icon: const Icon(Icons.rocket_launch_rounded),
                            label: const Text('Connect DevOps Suite'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_hasSearched)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildRepositorySelector(isDark, ref.watch(authenticatedUserProvider).valueOrNull),
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.settings_system_daydream_rounded,
                                size: 64,
                                color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.24),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a repository above or search to monitor build logs',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _RunsTab(owner: _ownerController.text.trim(), repo: _repoController.text.trim()),
                      _WorkflowsTab(owner: _ownerController.text.trim(), repo: _repoController.text.trim()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
  }

  Widget _buildRepositorySelector(bool isDark, GhUser? authUser) {
    final List<Map<String, dynamic>> popularRepos = [
      {'owner': 'flutter', 'name': 'flutter', 'label': 'Flutter', 'icon': Icons.flutter_dash_rounded},
      {'owner': 'facebook', 'name': 'react', 'label': 'React', 'icon': Icons.code_rounded},
      {'owner': 'dart-lang', 'name': 'sdk', 'label': 'Dart SDK', 'icon': Icons.terminal_rounded},
      {'owner': 'microsoft', 'name': 'vscode', 'label': 'VS Code', 'icon': Icons.desktop_mac_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Repository to Monitor CI/CD',
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
                        _search();
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
                              _search();
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
      ),
    );
  }
}

class _WorkflowTelemetryDashboard extends StatelessWidget {
  const _WorkflowTelemetryDashboard({required this.runs});
  final List runs;

  @override
  Widget build(BuildContext context) {
    int total = runs.length;
    int success = 0;
    int failure = 0;
    int running = 0;
    int queued = 0;
    double totalDurationSec = 0;
    int completedWithDuration = 0;

    for (final run in runs) {
      final status = run['status'] as String? ?? '';
      final conclusion = run['conclusion'] as String? ?? '';
      
      if (status == 'queued') {
        queued++;
      } else if (status == 'in_progress') {
        running++;
      } else if (status == 'completed') {
        if (conclusion == 'success') {
          success++;
        } else if (conclusion == 'failure') {
          failure++;
        }
      }

      final startStr = run['run_started_at'] as String?;
      final endStr = run['updated_at'] as String?;
      if (startStr != null && endStr != null) {
        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start != null && end != null) {
          final diff = end.difference(start).inSeconds;
          if (diff > 0) {
            totalDurationSec += diff;
            completedWithDuration++;
          }
        }
      }
    }

    final successRate = total > 0 ? (success / (success + failure == 0 ? 1 : success + failure)) : 0.0;
    final avgDurationSec = completedWithDuration > 0 ? (totalDurationSec / completedWithDuration).round() : 0;
    final avgDurationStr = avgDurationSec > 60 
        ? '${avgDurationSec ~/ 60}m ${avgDurationSec % 60}s'
        : '${avgDurationSec}s';

    final trendRuns = runs.take(10).toList().reversed.toList();

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          final chartWidget = SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 26,
                    startDegreeOffset: 270,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: success.toDouble() == 0 && failure.toDouble() == 0 ? 1 : success.toDouble(),
                        radius: 6,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: Colors.red,
                        value: failure.toDouble(),
                        radius: 6,
                        showTitle: false,
                      ),
                      if (running > 0 || queued > 0)
                        PieChartSectionData(
                          color: Colors.amber,
                          value: (running + queued).toDouble(),
                          radius: 6,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(successRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Text(
                      'Success',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          );

          final statsGrid = Column(
            children: [
              Row(
                children: [
                  _buildStatBox('Total Runs', '$total', Icons.playlist_play_rounded, Colors.blueAccent),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatBox('Avg Duration', avgDurationStr, Icons.timer_outlined, Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _buildStatBox('Succeeded', '$success', Icons.check_circle_rounded, Colors.green),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatBox('Failed', '$failure', Icons.cancel_rounded, Colors.red),
                ],
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Workflow Telemetry',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.sensors_rounded, color: Colors.greenAccent, size: 12),
                        SizedBox(width: 4),
                        Text('Live Metrics', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (isNarrow) ...[
                Center(child: chartWidget),
                const SizedBox(height: AppSpacing.md),
                statsGrid,
              ] else ...[
                Row(
                  children: [
                    chartWidget,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: statsGrid),
                  ],
                ),
              ],
              if (trendRuns.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: 8),
                const Text(
                  'Build Success History Trend (Last 10 Runs)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 35,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: trendRuns.map((run) {
                        final conclusion = run['conclusion'] as String? ?? '';
                        final status = run['status'] as String? ?? '';
                        Color dotColor = Colors.grey;
                        if (status == 'completed') {
                          dotColor = conclusion == 'success' ? Colors.green : Colors.red;
                        } else {
                          dotColor = Colors.amber;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: '${run['name']} #${run['run_number']} - ${conclusion.isEmpty ? status : conclusion}',
                            child: Container(
                              width: 22,
                              height: 30,
                              decoration: BoxDecoration(
                                color: dotColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: dotColor, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '#${run['run_number']}',
                                  style: TextStyle(color: dotColor, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsTab extends ConsumerWidget {
  const _RunsTab({required this.owner, required this.repo});
  final String owner;
  final String repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(workflowRunsFutureProvider((owner: owner, repo: repo)));

    return runsAsync.when(
      data: (data) {
        final List runs = data['workflow_runs'] ?? [];
        if (runs.isEmpty) {
          return const Center(child: Text('No workflow runs found.'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workflowRunsFutureProvider((owner: owner, repo: repo)));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: runs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _WorkflowTelemetryDashboard(runs: runs);
              }
              final run = runs[index - 1];
              final status = run['status'] as String? ?? '';
              final conclusion = run['conclusion'] as String? ?? '';
              final headCommit = run['head_commit'] ?? {};
              final message = headCommit['message'] as String? ?? 'No commit message';
              final author = headCommit['author']?['name'] as String? ?? 'Unknown';
              final branch = run['head_branch'] as String? ?? 'main';
              final runNumber = run['run_number'] ?? 0;
              final workflowName = run['name'] as String? ?? 'Workflow';

              // Calculate run duration
              final startTimeStr = run['run_started_at'] as String?;
              final endTimeStr = run['updated_at'] as String?;
              String durationText = '';
              if (startTimeStr != null && endTimeStr != null) {
                final startTime = DateTime.tryParse(startTimeStr);
                final endTime = DateTime.tryParse(endTimeStr);
                if (startTime != null && endTime != null) {
                  final diff = endTime.difference(startTime);
                  if (diff.inMinutes > 0) {
                    durationText = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
                  } else {
                    durationText = '${diff.inSeconds}s';
                  }
                }
              }

              Color statusColor = Colors.grey;
              IconData statusIcon = Icons.help_outline_rounded;
              bool spinning = false;

              if (status == 'queued') {
                statusColor = Colors.amber;
                statusIcon = Icons.hourglass_empty_rounded;
              } else if (status == 'in_progress') {
                statusColor = Colors.blue;
                statusIcon = Icons.sync_rounded;
                spinning = true;
              } else if (status == 'completed') {
                if (conclusion == 'success') {
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle_rounded;
                } else if (conclusion == 'failure') {
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel_rounded;
                } else if (conclusion == 'cancelled') {
                  statusColor = Colors.grey;
                  statusIcon = Icons.block_rounded;
                }
              }

              return AppSurface(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkflowRunDetailsScreen(
                        owner: owner,
                        repo: repo,
                        runId: run['id'],
                        runNumber: runNumber,
                        workflowName: workflowName,
                        commitMessage: message,
                        status: status,
                        conclusion: conclusion,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (spinning)
                        const GlowingIndicator(size: 20)
                      else
                        Icon(statusIcon, color: statusColor, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.split('\n').first,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '$workflowName #$runNumber • $branch',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (durationText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 2),
                                  Text(
                                    durationText,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Triggered by $author',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: GlowingIndicator()),
      error: (e, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: ${e.toString()}', textAlign: TextAlign.center,),
      )),
    );
  }
}

class _WorkflowsTab extends ConsumerWidget {
  const _WorkflowsTab({required this.owner, required this.repo});
  final String owner;
  final String repo;

  void _showTriggerDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> workflow) {
    final name = workflow['name'] as String? ?? 'Workflow';
    final workflowId = workflow['id'];
    final refController = TextEditingController(text: 'main');
    final Map<String, String> inputs = {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trigger $name'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: 'Branch/Tag/Commit Ref',
                  hintText: 'e.g. main',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Note: Standard inputs for manual trigger can be supplied if required by your workflow.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final api = ref.read(githubApiServiceProvider);
                await api.triggerWorkflowDispatch(
                  owner,
                  repo,
                  workflowId,
                  ref: refController.text.trim(),
                  inputs: inputs,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workflow dispatch triggered successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to trigger workflow: ${e.toString()}')),
                );
              }
            },
            child: const Text('Trigger Dispatch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowsAsync = ref.watch(workflowsFutureProvider((owner: owner, repo: repo)));

    return workflowsAsync.when(
      data: (data) {
        final List workflows = data['workflows'] ?? [];
        if (workflows.isEmpty) {
          return const Center(child: Text('No workflows found in this repo.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: workflows.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final w = workflows[index];
            final name = w['name'] as String? ?? 'Workflow';
            final path = w['path'] as String? ?? '';
            final state = w['state'] as String? ?? 'active';

            return AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest_rounded, color: AppColors.accent, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(path, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (state == 'active')
                      Consumer(
                        builder: (context, ref, _) {
                          final pat = ref.watch(githubPatProvider);
                          final isLoggedIn = pat != null && pat.isNotEmpty;
                          return IconButton(
                            icon: Icon(
                              isLoggedIn ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded,
                              color: isLoggedIn ? Colors.green : Colors.grey,
                              size: 30,
                            ),
                            onPressed: () {
                              if (!isLoggedIn) {
                                showDialog(context: context, builder: (_) => const AuthDialog());
                              } else {
                                _showTriggerDialog(context, ref, w);
                              }
                            },
                            tooltip: isLoggedIn ? 'Trigger manually (workflow_dispatch)' : 'Login to trigger workflow',
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: GlowingIndicator()),
      error: (e, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: ${e.toString()}', textAlign: TextAlign.center,),
      )),
    );
  }
}

class WorkflowRunDetailsScreen extends ConsumerStatefulWidget {
  const WorkflowRunDetailsScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.runId,
    required this.runNumber,
    required this.workflowName,
    required this.commitMessage,
    required this.status,
    required this.conclusion,
  });

  final String owner;
  final String repo;
  final dynamic runId;
  final int runNumber;
  final String workflowName;
  final String commitMessage;
  final String status;
  final String conclusion;

  @override
  ConsumerState<WorkflowRunDetailsScreen> createState() => _WorkflowRunDetailsScreenState();
}

class _WorkflowRunDetailsScreenState extends ConsumerState<WorkflowRunDetailsScreen> {
  late Future<Map<String, dynamic>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  void _fetchJobs() {
    _jobsFuture = ref.read(githubApiServiceProvider).getWorkflowRunJobs(widget.owner, widget.repo, widget.runId);
  }

  Future<void> _rerun() async {
    final pat = ref.read(githubPatProvider);
    final isLoggedIn = pat != null && pat.isNotEmpty;
    if (!isLoggedIn) {
      showDialog(context: context, builder: (_) => const AuthDialog());
      return;
    }
    try {
      await ref.read(githubApiServiceProvider).rerunWorkflow(widget.owner, widget.repo, widget.runId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow re-run requested!')),
      );
      setState(() {
        _fetchJobs();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to re-run: ${e.toString()}')),
      );
    }
  }

  Future<void> _cancel() async {
    final pat = ref.read(githubPatProvider);
    final isLoggedIn = pat != null && pat.isNotEmpty;
    if (!isLoggedIn) {
      showDialog(context: context, builder: (_) => const AuthDialog());
      return;
    }
    try {
      await ref.read(githubApiServiceProvider).cancelWorkflow(widget.owner, widget.repo, widget.runId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow run cancellation requested!')),
      );
      setState(() {
        _fetchJobs();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('${widget.workflowName} #${widget.runNumber}'),
          actions: [
            if (widget.status == 'in_progress' || widget.status == 'queued')
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                onPressed: _cancel,
                tooltip: 'Cancel Run',
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.green),
                onPressed: _rerun,
                tooltip: 'Re-run Jobs',
              )
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _jobsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: GlowingIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading jobs: ${snapshot.error}'));
            }

            final List jobs = snapshot.data?['jobs'] ?? [];
            if (jobs.isEmpty) {
              return const Center(child: Text('No jobs found for this run.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final job = jobs[index];
                final jobName = job['name'] as String? ?? 'Job';
                final jobStatus = job['status'] as String? ?? '';
                final jobConclusion = job['conclusion'] as String? ?? '';
                final List steps = job['steps'] ?? [];

                return AppSurface(
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        _getStatusIcon(jobStatus, jobConclusion),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(jobName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.all(AppSpacing.md),
                    expandedAlignment: Alignment.topLeft,
                    children: [
                      const Text(
                        'Steps:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...steps.map((step) {
                        final stepName = step['name'] as String? ?? 'Step';
                        final stepStatus = step['status'] as String? ?? '';
                        final stepConclusion = step['conclusion'] as String? ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              _getStatusIcon(stepStatus, stepConclusion, size: 16),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  stepName,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobLogsScreen(
                                  owner: widget.owner,
                                  repo: widget.repo,
                                  jobId: job['id'],
                                  jobName: jobName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.terminal_rounded),
                          label: const Text('View Build Logs'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _getStatusIcon(String status, String conclusion, {double size = 20}) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline_rounded;

    if (status == 'queued') {
      statusColor = Colors.amber;
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (status == 'in_progress') {
      return GlowingIndicator(size: size);
    } else if (status == 'completed') {
      if (conclusion == 'success') {
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
      } else if (conclusion == 'failure') {
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
      } else if (conclusion == 'cancelled') {
        statusColor = Colors.grey;
        statusIcon = Icons.block_rounded;
      }
    }

    return Icon(statusIcon, color: statusColor, size: size);
  }
}

class JobLogsScreen extends ConsumerStatefulWidget {
  const JobLogsScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.jobId,
    required this.jobName,
  });

  final String owner;
  final String repo;
  final dynamic jobId;
  final String jobName;

  @override
  ConsumerState<JobLogsScreen> createState() => _JobLogsScreenState();
}

class _JobLogsScreenState extends ConsumerState<JobLogsScreen> {
  late Future<String> _logsFuture;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _logsFuture = ref.read(githubApiServiceProvider).getJobLogs(widget.owner, widget.repo, widget.jobId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafePage(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark slate console background
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                )
              : Text(widget.jobName, style: const TextStyle(fontFamily: 'monospace')),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
        ),
        body: FutureBuilder<String>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: GlowingIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error loading logs: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final logText = snapshot.data ?? 'No logs available.';
            final spans = _parseAnsiToTextSpans(
              logText,
              const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: Color(0xFFE2E8F0),
              ),
            );

            return SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                physics: const BouncingScrollPhysics(),
                child: Text.rich(
                  TextSpan(children: spans),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<InlineSpan> _highlightSearchMatches(String segment, TextStyle style) {
    if (_searchQuery.isEmpty) {
      final lower = segment.toLowerCase();
      Color? textCol;
      if (lower.contains('error') || lower.contains('failed') || lower.contains('exception') || lower.contains('fail')) {
        textCol = Colors.redAccent;
      } else if (lower.contains('warning') || lower.contains('warn')) {
        textCol = Colors.amberAccent;
      }
      return [
        TextSpan(
          text: segment,
          style: style.copyWith(color: textCol),
        ),
      ];
    }

    final List<InlineSpan> spans = [];
    final lowerSegment = segment.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    int start = 0;
    int index = lowerSegment.indexOf(lowerQuery, start);

    while (index != -1) {
      if (index > start) {
        final prefix = segment.substring(start, index);
        spans.add(TextSpan(text: prefix, style: style));
      }

      final matchText = segment.substring(index, index + _searchQuery.length);
      spans.add(TextSpan(
        text: matchText,
        style: style.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.35),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));

      start = index + _searchQuery.length;
      index = lowerSegment.indexOf(lowerQuery, start);
    }

    if (start < segment.length) {
      final suffix = segment.substring(start);
      spans.add(TextSpan(text: suffix, style: style));
    }

    return spans;
  }

  List<InlineSpan> _parseAnsiToTextSpans(String text, TextStyle defaultStyle) {
    final List<InlineSpan> spans = [];
    final RegExp ansiRegex = RegExp(r'\u001b\[([0-9;]*)m');

    int lastIndex = 0;
    Color currentColor = const Color(0xFFE2E8F0);
    bool isBold = false;

    for (final match in ansiRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final part = text.substring(lastIndex, match.start);
        spans.addAll(_highlightSearchMatches(
          part,
          defaultStyle.copyWith(
            color: currentColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ));
      }

      final code = match.group(1) ?? '';
      if (code.isEmpty || code == '0') {
        currentColor = const Color(0xFFE2E8F0);
        isBold = false;
      } else {
        final parts = code.split(';');
        for (final p in parts) {
          final val = int.tryParse(p);
          if (val == null) continue;
          if (val == 1) {
            isBold = true;
          } else if (val >= 30 && val <= 37) {
            currentColor = _ansiColorMap[val] ?? currentColor;
          } else if (val == 39) {
            currentColor = const Color(0xFFE2E8F0);
          }
        }
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final part = text.substring(lastIndex);
      spans.addAll(_highlightSearchMatches(
        part,
        defaultStyle.copyWith(
          color: currentColor,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ));
    }

    return spans;
  }

  static const Map<int, Color> _ansiColorMap = {
    30: Colors.black,
    31: Colors.redAccent,
    32: Colors.greenAccent,
    33: Colors.amberAccent,
    34: Colors.blueAccent,
    35: Colors.purpleAccent,
    36: Colors.cyanAccent,
    37: Colors.white,
  };
}
