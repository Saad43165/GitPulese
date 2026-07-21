import 'package:gitexplorer/core/network/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/github_api_service.dart';
import '../../data/models/user_and_search_models.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';

enum TriageFilter { allOpenIssues, allOpenPRs }

final triageFilterProvider = StateProvider.autoDispose<TriageFilter>((ref) => TriageFilter.allOpenIssues);

class TriageState {
  final List<GhIssue> items;
  final int totalCount;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;

  TriageState({
    required this.items,
    required this.totalCount,
    required this.isLoading,
    required this.isLoadingMore,
    required this.error,
    required this.currentPage,
  });

  TriageState copyWith({
    List<GhIssue>? items,
    int? totalCount,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
  }) {
    return TriageState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class TriageNotifier extends StateNotifier<TriageState> {
  final GitHubApiService _api;
  final String _owner;
  final String _repo;
  final TriageFilter _filter;

  TriageNotifier({
    required GitHubApiService api,
    required String owner,
    required String repo,
    required TriageFilter filter,
  })  : _api = api,
        _owner = owner,
        _repo = repo,
        _filter = filter,
        super(TriageState(
          items: [],
          totalCount: 0,
          isLoading: true,
          isLoadingMore: false,
          error: null,
          currentPage: 1,
        )) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null, currentPage: 1, items: []);
    try {
      final res = await _api.searchIssues(
        query: 'repo:$_owner/$_repo sort:created-asc',
        pullRequestsOnly: _filter == TriageFilter.allOpenPRs,
        state: 'open',
        page: 1,
        perPage: 25,
      );
      state = state.copyWith(
        items: res.items,
        totalCount: res.totalCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e is GitHubApiException ? e.message : e.toString());
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || state.items.length >= state.totalCount) return;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;
    try {
      final res = await _api.searchIssues(
        query: 'repo:$_owner/$_repo sort:created-asc',
        pullRequestsOnly: _filter == TriageFilter.allOpenPRs,
        state: 'open',
        page: nextPage,
        perPage: 25,
      );
      state = state.copyWith(
        items: [...state.items, ...res.items],
        currentPage: nextPage,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final triageNotifierProvider = StateNotifierProvider.autoDispose
    .family<TriageNotifier, TriageState, ({String owner, String repo})>((ref, args) {
  final filter = ref.watch(triageFilterProvider);
  final api = ref.watch(githubApiServiceProvider);
  return TriageNotifier(api: api, owner: args.owner, repo: args.repo, filter: filter);
});

class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key, required this.owner, required this.repoName});
  final String owner;
  final String repoName;

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  final ScrollController _scrollController = ScrollController();
  late final ({String owner, String repo}) _args;

  @override
  void initState() {
    super.initState();
    _args = (owner: widget.owner, repo: widget.repoName);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(triageNotifierProvider(_args).notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(triageFilterProvider);
    final triageState = ref.watch(triageNotifierProvider(_args));

    return DecoratedBox(
      decoration: AppDecorations.pageGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('${widget.owner}/${widget.repoName}'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                showBackButton: false,
                title: 'Maintainer Triage',
                subtitle: triageState.isLoading
                    ? 'Fetching repository backlog...'
                    : 'Showing oldest items first · ${triageState.totalCount} open total',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: SegmentedButton<TriageFilter>(
                  segments: const [
                    ButtonSegment(value: TriageFilter.allOpenIssues, label: Text('Issues')),
                    ButtonSegment(value: TriageFilter.allOpenPRs, label: Text('Pull Requests')),
                  ],
                  selected: {filter},
                  onSelectionChanged: (s) => ref.read(triageFilterProvider.notifier).state = s.first,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (triageState.isLoading) {
                      return const ShimmerList();
                    }

                    if (triageState.error != null) {
                      return ErrorStateView(
                        message: triageState.error!,
                        onRetry: () => ref.read(triageNotifierProvider(_args).notifier).loadFirstPage(),
                      );
                    }

                    if (triageState.items.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.task_alt_rounded,
                        title: 'Queue is clear',
                        subtitle: 'No open issues or pull requests right now',
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        0,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xxl,
                      ),
                      itemCount: triageState.items.length + (triageState.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        if (i == triageState.items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: GlowingIndicator(size: 24),
                            ),
                          );
                        }

                        final issue = triageState.items[i];
                        final ageDays = DateTime.now().difference(issue.createdAt).inDays;
                        final isStale = ageDays > 90;
                        final accent = isStale ? AppColors.danger : AppColors.accent;

                        return AppSurface(
                          onTap: () => launchUrl(
                            Uri.parse(issue.htmlUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          showAccentStripe: true,
                          accentColor: accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isStale)
                                    Container(
                                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      ),
                                      child: const Text(
                                        'STALE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      '#${issue.number} ${issue.title}',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Text(
                                    'Opened ${timeago.format(issue.createdAt)}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: isStale
                                              ? AppColors.danger
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${issue.comments}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
