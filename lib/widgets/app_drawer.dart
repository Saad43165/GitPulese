import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/core_providers.dart';
import '../providers/settings_providers.dart';
import '../features/settings/settings_screen.dart';

import '../features/bookmarks/bookmarks_screen.dart';
import '../features/tracked_repos/tracked_repos_screen.dart';
import '../features/auth/auth_dialog.dart';
import '../features/user_detail/user_detail_screen.dart';
import '../features/editor/ai_code_editor_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authenticatedUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgChecks = ref.watch(backgroundChecksEnabledProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: MediaQuery.of(context).size.width * 0.8,
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
                                const Color(0xFF161B22).withValues(alpha: 0.85),
                                const Color(0xFF0D1117).withValues(alpha: 0.95),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.85),
                                const Color(0xFFF3F4F6).withValues(alpha: 0.95),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        right: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
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
                  // Beautiful Header
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 24, bottom: 24),
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
                          loading: () => const CircleAvatar(radius: 40, backgroundColor: Colors.black45),
                          error: (_, __) => const CircleAvatar(radius: 40, backgroundColor: Colors.black45),
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
                                      width: 48,
                                      height: 48,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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
                                    label: const Text('Continue with GitHub'),
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
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UserDetailScreen(username: user.login),
                                  ),
                                );
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          )
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      user.name ?? user.login,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
      
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  const SizedBox(height: 16),
      
                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.home_rounded,
                          title: 'Command Center',
                          iconColor: const Color(0xFF8B5CF6),
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.bookmark_rounded,
                          title: 'Saved Collections',
                          iconColor: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen()));
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
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackedReposScreen()));
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.code_rounded,
                          title: 'AI Code Editor',
                          iconColor: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiCodeEditorScreen()));
                          },
                        ),
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.settings_rounded,
                          title: 'App Settings',
                          iconColor: Colors.grey,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          },
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          child: Text(
                            'PREFERENCES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.2,
                            ),
                          ),
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
                        _buildNavItem(
                          context,
                          isDark: isDark,
                          icon: Icons.notifications_active_rounded,
                          title: 'Background Sync',
                          iconColor: Colors.grey,
                          trailing: Switch(
                            value: bgChecks,
                            onChanged: (val) {
                              ref.read(backgroundChecksEnabledProvider.notifier).setEnabled(val);
                            },
                            activeColor: AppColors.accent,
                            activeTrackColor: AppColors.accent.withValues(alpha: 0.2),
                          ),
                          onTap: () {
                            ref.read(backgroundChecksEnabledProvider.notifier).setEnabled(!bgChecks);
                          },
                        ),
                      ],
                    ),
                  ),
      
                   // Footer: Log Out only (shown when signed in)
                  authUser.when(
                    data: (user) {
                      if (user == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
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

  Widget _buildNavItem(BuildContext context, {required bool isDark, required IconData icon, required String title, required Color iconColor, required VoidCallback onTap, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
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
