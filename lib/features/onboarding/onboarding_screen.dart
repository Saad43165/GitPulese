import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_providers.dart';
import '../auth/auth_dialog.dart';
import '../../widgets/glowing_indicator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final Widget preview;

  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.preview,
  });
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _contentCtrl;
  late final PageController _slideController;

  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _featuresFade;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  int _currentIndex = 0;

  late final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.search_rounded,
      color: const Color(0xFF6366F1),
      title: 'Smart Git Discovery',
      description: 'Search millions of public repositories, organizations, profiles, and code snippets instantly.',
      preview: _DiscoveryPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.psychology_rounded,
      color: const Color(0xFF8B5CF6),
      title: 'AI PR Reviewer & Security',
      description: 'Paste any GitHub PR link to automatically analyze diffs for security vulnerabilities and code quality.',
      preview: _PrReviewPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.rocket_launch_rounded,
      color: const Color(0xFF0EA5E9),
      title: 'Mobile DevOps Control',
      description: 'Trigger workflows, stream live build logs, and monitor CI/CD status on the go.',
      preview: _DevOpsPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.code_rounded,
      color: const Color(0xFF10B981),
      title: 'AI Code Editor & Vault',
      description: 'Refactor code files using AI prompts, inspect side-by-side git diffs, and save offline codebase snapshots.',
      preview: _EditorPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.bubble_chart_rounded,
      color: const Color(0xFFF59E0B),
      title: 'Git Commit Visualizer',
      description: 'Explore calculated codebase complexity, test coverage, and interactive radial commit trees.',
      preview: _VisualizerPreview(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = PageController();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _logoSlide = Tween<Offset>(
            begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));

    _titleFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.2, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic)));

    _featuresFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut));

    _buttonsFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut));
    _buttonsSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _contentCtrl.forward();
    });

    ref.listenManual(githubPatProvider, (_, pat) {
      if (pat != null && pat.isNotEmpty && mounted) {
        _navigateToApp();
      }
    });
  }

  void _navigateToApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg, // Pure Obsidian (#090D16) matching icon
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Clean Logo (Original app icon, seamlessly blending with #090D16)
              FadeTransition(
                opacity: _logoFade,
                child: SlideTransition(
                  position: _logoSlide,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/icon_1.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title & Headline
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Git',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA5B4FC)],
                            ).createShader(bounds),
                            child: Text(
                              'Pulse',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your complete GitHub mobile workspace.\nDiscover code, review PRs & track DevOps — all in one app.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Feature Slider
              FadeTransition(
                opacity: _featuresFade,
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        controller: _slideController,
                        itemCount: _slides.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                          HapticFeedback.selectionClick();
                        },
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return _OnboardingSlideWidget(slide: slide);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
                        final isSelected = _currentIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: isSelected ? 22 : 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Sign in & Browse CTAs
              FadeTransition(
                opacity: _buttonsFade,
                child: SlideTransition(
                  position: _buttonsSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Continue with GitHub Button (with Recommended Badge)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  showDialog(
                                    context: context,
                                    builder: (_) => const AuthDialog(),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/github.png',
                                        width: 20,
                                        height: 20,
                                        color: Colors.white,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.code_rounded,
                                                color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Continue with GitHub PAT',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -10,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'RECOMMENDED (5,000 req/hr)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      const SizedBox(height: 10),

                      // OAuth Login button
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push(AppRoutes.login);
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Login with GitHub (OAuth)'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),

                      // Browse as Guest button
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _navigateToApp();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'Browse as Guest (Limited to 60 req/hr) →',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Connecting a token unlocks 5,000 req/hr, private repos & CI/CD tools.\nToken is stored 100% encrypted on device.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideWidget extends StatelessWidget {
  final _OnboardingSlide slide;

  const _OnboardingSlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: slide.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(slide.icon, color: slide.color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              slide.title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          height: 95,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: slide.preview,
        ),
      ],
    );
  }
}

// ── Slide Previews ─────────────────────────────────────────

class _DiscoveryPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Search libraries, orgs, APIs...',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildChip('flutter', const Color(0xFF6366F1)),
            const SizedBox(width: 6),
            _buildChip('ai-reviewer', const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            _buildChip('devops', const Color(0xFF10B981)),
          ],
        )
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '#$label',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DevOpsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GlowingIndicator(size: 14),
              SizedBox(width: 8),
              Text(
                'build_apk (run #42)',
                style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          Text(
            'Running',
            style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EditorPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.greenAccent, size: 12),
              SizedBox(width: 6),
              Text('AI Code Refactoring Patch', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            color: Colors.greenAccent.withValues(alpha: 0.15),
            child: const Text(
              '+ final total = Iterable.generate(100).reduce((a, b) => a + b);',
              style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrReviewPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.call_merge_rounded, color: Colors.green, size: 12),
              SizedBox(width: 6),
              Text('PR #12 - Fix Memory Leak', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 6),
          _buildCodeLine('- controller.dispose();', Colors.redAccent.withValues(alpha: 0.15), Colors.redAccent),
          _buildCodeLine('+ super.dispose();', Colors.greenAccent.withValues(alpha: 0.15), Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildCodeLine(String text, Color bg, Color textCol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 9, fontFamily: 'monospace'),
      ),
    );
  }
}

class _VisualizerPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricDial('Complexity', 'Medium', Colors.amberAccent),
          _buildMetricDial('Coverage', '82%', Colors.greenAccent),
          _buildMetricDial('Security Risk', 'Low', AppColors.accentSoft),
        ],
      ),
    );
  }

  Widget _buildMetricDial(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle_outlined, color: color, size: 10),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
      ],
    );
  }
}
