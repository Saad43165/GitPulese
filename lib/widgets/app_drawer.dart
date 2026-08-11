import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/core_providers.dart';
import '../providers/settings_providers.dart';
import '../features/auth/auth_dialog.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: MediaQuery.of(context).size.width * 0.82,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Stack(
          children: [
            // Glassmorphic Gradient Background
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [
                                AppColors.darkBg.withValues(alpha: 0.95),
                                AppColors.darkSurface.withValues(alpha: 0.98),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.92),
                                const Color(0xFFF1F5F9).withValues(alpha: 0.98),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        right: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // User Profile / Sign In Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
                            ),
                          ),
                        ),
                        authUser.when(
                          loading: () => const CircleAvatar(radius: 36, backgroundColor: Colors.black26),
                          error: (_, __) => const CircleAvatar(radius: 36, backgroundColor: Colors.black26),
                          data: (user) {
                            if (user == null) {
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                      border: Border.all(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                      ),
                                    ),
                                    child: Image.asset(
                                      'assets/images/github.png',
                                      width: 40,
                                      height: 40,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showDialog(context: context, builder: (_) => const AuthDialog());
                                    },
                                    icon: Image.asset(
                                      'assets/images/github.png',
                                      width: 16,
                                      height: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text('Sign In to GitHub'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                context.push(AppRoutes.userPath(user.login));
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    user.name ?? user.login,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
      
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
                  ),
                  const SizedBox(height: 12),
      
                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionHeader('MAIN HUB', isDark),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.notifications_rounded,
                          title: 'Notifications Center',
                          iconColor: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.notifications);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.bookmark_rounded,
                          title: 'Saved Collections',
                          iconColor: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.bookmarks);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.radar_rounded,
                          title: 'Tracked Releases',
                          iconColor: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.tracked);
                          },
                        ),
                        
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.business_rounded,
                          title: 'Organizations',
                          iconColor: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.orgs);
                          },
                        ),
                        _buildSectionHeader('AI & DEV TOOLS', isDark),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.code_rounded,
                          title: 'AI Code Editor',
                          iconColor: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.editor);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.rate_review_rounded,
                          title: 'AI PR Reviewer',
                          iconColor: const Color(0xFF6366F1),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.prReview);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.rocket_launch_rounded,
                          title: 'DevOps CI/CD Workflows',
                          iconColor: const Color(0xFFEF4444),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.devops);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.code_off_rounded,
                          title: 'GitHub Gists Explorer',
                          iconColor: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.gists);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.offline_pin_rounded,
                          title: 'Offline Codebase Vault',
                          iconColor: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.vault);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.timeline_rounded,
                          title: 'My Activity Feed',
                          iconColor: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.pop(context);
                            final username = authUser.valueOrNull?.login;
                            if (username != null) {
                              context.push(AppRoutes.activityPath(username));
                            } else {
                              showDialog(context: context, builder: (_) => const AuthDialog());
                            }
                          },
                        ),
                        
                        _buildSectionHeader('PREFERENCES', isDark),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.settings_rounded,
                          title: 'App Settings',
                          iconColor: Colors.grey,
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.settings);
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          title: 'Dark Theme',
                          iconColor: Colors.grey,
                          trailing: Switch(
                            value: isDark,
                            onChanged: (val) {
                              final newMode = val ? ThemeMode.dark : ThemeMode.light;
                              ref.read(themeModeProvider.notifier).setMode(newMode);
                            },
                            activeColor: AppColors.accent,
                            activeTrackColor: AppColors.accent.withValues(alpha: 0.2),
                          ),
                          onTap: () {
                            final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                            ref.read(themeModeProvider.notifier).setMode(newMode);
                          },
                        ),
                      ],
                    ),
                  ),
      
                  // Footer
                  authUser.when(
                    data: (user) {
                      if (user == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildAuthAction(
                          context,
                          isDark: isDark,
                          icon: Icons.logout_rounded,
                          title: 'Log Out of GitHub',
                          onTap: () async {
                            await ref.read(githubPatProvider.notifier).save(null);
                            ref.read(demoUsernameProvider.notifier).state = null;
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required bool isDark, required IconData icon, required String title, required Color iconColor, required VoidCallback onTap, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthAction(BuildContext context, {required bool isDark, required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 18),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
