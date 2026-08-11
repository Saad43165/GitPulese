import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/repo_model.dart';
import '../../data/models/user_and_search_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/state_views.dart';

final _userOrgsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getUserOrgs();
});

final _orgReposProvider = FutureProvider.autoDispose.family<List<GhRepo>, String>((ref, org) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getOrgRepos(org);
});

final _orgMembersProvider = FutureProvider.autoDispose.family<List<GhUser>, String>((ref, org) async {
  final api = ref.watch(githubApiServiceProvider);
  return api.getOrgMembers(org);
});

class OrgsScreen extends ConsumerWidget {
  const OrgsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pat = ref.watch(githubPatProvider);
    final isLoggedIn = pat != null && pat.isNotEmpty;

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Organizations'),
          backgroundColor: const Color(0xFF0D1117),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded, size: 56, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'Sign in to view your organizations',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final orgsAsync = ref.watch(_userOrgsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Organizations'),
        backgroundColor: const Color(0xFF0D1117),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_userOrgsProvider),
          ),
        ],
      ),
      body: orgsAsync.when(
        data: (orgs) {
          if (orgs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.business_outlined,
              title: 'No organizations',
              subtitle: 'You are not a member of any organization',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orgs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _OrgCard(org: orgs[i]),
          );
        },
        loading: () => const Center(child: GlowingIndicator(size: 32)),
        error: (e, _) => ErrorStateView(
          message: e is GitHubApiException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(_userOrgsProvider),
        ),
      ),
    );
  }
}

class _OrgCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> org;

  const _OrgCard({required this.org});

  @override
  ConsumerState<_OrgCard> createState() => _OrgCardState();
}

class _OrgCardState extends ConsumerState<_OrgCard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.org;
    final login = org['login'] as String? ?? '';
    final description = org['description'] as String? ?? '';
    final avatarUrl = org['avatar_url'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (avatarUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, color: AppColors.accent, size: 22),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          login,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Repos'),
                Tab(text: 'Members'),
              ],
            ),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OrgRepos(org: login),
                  _OrgMembers(org: login),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrgRepos extends ConsumerWidget {
  final String org;

  const _OrgRepos({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposAsync = ref.watch(_orgReposProvider(org));

    return reposAsync.when(
      data: (repos) {
        if (repos.isEmpty) {
          return const Center(
            child: Text('No repos', style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: repos.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final repo = repos[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(repo.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: repo.description != null
                  ? Text(
                      repo.description!,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_border_rounded, size: 13, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text(
                    '${repo.stargazersCount}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              onTap: () => context.push(AppRoutes.repoPath(repo.owner.login, repo.name)),
            );
          },
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 24)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    );
  }
}

class _OrgMembers extends ConsumerWidget {
  final String org;

  const _OrgMembers({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_orgMembersProvider(org));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const Center(
            child: Text('No members', style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: members.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final member = members[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                radius: 16,
                backgroundImage: CachedNetworkImageProvider(member.avatarUrl),
              ),
              title: Text(
                member.login,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              onTap: () => context.push(AppRoutes.userPath(member.login)),
            );
          },
        );
      },
      loading: () => const Center(child: GlowingIndicator(size: 24)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    );
  }
}
