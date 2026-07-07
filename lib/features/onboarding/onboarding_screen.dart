import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_providers.dart';
import '../auth/auth_dialog.dart';
import '../home/root_shell.dart';

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
  late final AnimationController _bgCtrl;
  late final AnimationController _contentCtrl;
  late final PageController _slideController;

  late final Animation<double> _bgAnim;
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
      color: const Color(0xFF3B82F6),
      title: 'Smart Git Discovery',
      description: 'Search millions of public repositories, organizations, profiles, and code snippets instantly.',
      preview: _DiscoveryPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.psychology_rounded,
      color: const Color(0xFF8B5CF6),
      title: 'AI PR Reviewer',
      description: 'Paste any GitHub PR link to automatically analyze diffs for security issues, bugs, and performance tweaks.',
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
      title: 'AI Code Editor & Git Patch',
      description: 'Refactor code files using AI prompts, view side-by-side git diffs, and commit patches directly.',
      preview: _EditorPreview(),
    ),
    _OnboardingSlide(
      icon: Icons.bubble_chart_rounded,
      color: const Color(0xFFF59E0B),
      title: 'Codebase Visualizer',
      description: 'Explore calculated codebase complexity, test coverage, and visual radial package structure.',
      preview: _VisualizerPreview(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = PageController();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bgAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_bgCtrl);

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

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _contentCtrl.forward();
    });

    // Watch for sign-in and navigate automatically
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
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) => const RootShell(),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _contentCtrl.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgCtrl, _contentCtrl]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Radial orbits background
              CustomPaint(
                painter: _OrbitPainter(animation: _bgAnim),
                size: size,
              ),

              // Main onboarding content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Logo
                      FadeTransition(
                        opacity: _logoFade,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      AppColors.accent.withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.asset(
                                    'assets/icons/icon_1.png',
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/icons/app_icon.png',
                                      width: 80,
                                      height: 80,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

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
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Color(0xFF60A5FA), Color(0xFF9333EA)],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Pulse',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your complete GitHub command center.\nDiscover, track & analyze — all in one place.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Redesigned Interactive Feature Slider
                      FadeTransition(
                        opacity: _featuresFade,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 230,
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
                            const SizedBox(height: 16),
                            // Liquid dot page indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_slides.length, (index) {
                                final isSelected = _currentIndex == index;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 6,
                                  width: isSelected ? 20 : 6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent
                                        : Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Sign in & Browse CTA Group
                      FadeTransition(
                        opacity: _buttonsFade,
                        child: SlideTransition(
                          position: _buttonsSlide,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Continue with GitHub Button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF9333EA).withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
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
                                            'Continue with GitHub',
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

                              const SizedBox(height: 10),

                              // Browse without account button
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _navigateToApp();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'Browse without signing in →',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Privacy legal notice
                              Text(
                                'Your Personal Access Token is stored securely on-device only.\nWe never transmit your data.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.25),
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
            ],
          );
        },
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
        // Slide header icon and title
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
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Custom visual preview widget container
        Container(
          width: double.infinity,
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 24),
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
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: const [
              Icon(Icons.search_rounded, color: Colors.blueAccent, size: 16),
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
            _buildChip('flutter', Colors.blue),
            const SizedBox(width: 6),
            _buildChip('ai-reviewer', Colors.purple),
            const SizedBox(width: 6),
            _buildChip('analytics', Colors.green),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
              ),
              SizedBox(width: 8),
              Text(
                'build_apk (run #42)',
                style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Running',
              style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
            ),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricDial('Complexity', 'Medium', Colors.amberAccent),
          _buildMetricDial('Coverage', '82%', Colors.greenAccent),
          _buildMetricDial('Security Risk', 'Low', Colors.blueAccent),
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

// ── Animated orbit background painter ─────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.animation}) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    final t = animation.value;

    // Draw pulsing glow rings
    for (int i = 3; i >= 0; i--) {
      final radius = 80.0 + i * 70.0 + sin(t * 2 * pi + i * 0.8) * 8;
      final alpha = (0.06 - i * 0.012).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Draw rotating dots
    const dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final angle = (t * 2 * pi) + (i / dotCount) * 2 * pi;
      final r = 120.0 + (i % 3) * 65.0;
      final dx = cx + r * cos(angle);
      final dy = cy + r * sin(angle * 0.6);
      final dotAlpha = 0.15 + 0.1 * sin(t * 2 * pi * 2 + i);
      canvas.drawCircle(
        Offset(dx, dy),
        2.0,
        Paint()..color = const Color(0xFF60A5FA).withValues(alpha: dotAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}
