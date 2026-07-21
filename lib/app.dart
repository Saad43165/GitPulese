import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'providers/core_providers.dart';
import 'providers/settings_providers.dart';
import 'widgets/global_zip_progress_overlay.dart';

class GitPulseApp extends ConsumerWidget {
  const GitPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Eagerly load persisted GitHub PAT so API calls use it from first request.
    ref.watch(githubPatProvider);

    return MaterialApp(
      title: 'GitPulse',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      ),
      // ignore: deprecated_member_use
      builder: (context, child) => ShowCaseWidget(
        enableAutoScroll: true,
        // ignore: deprecated_member_use
        builder: (context) => GlobalZipProgressOverlay(child: child!),
      ),
      home: const SplashScreen(),
    );
  }
}
