import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../home/root_shell.dart';
import '../onboarding/onboarding_screen.dart';
import '../../core/constants/api_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _orbitCtrl;
  late final AnimationController _starCtrl;

  // Icon entry
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  // Text entry
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  // Loader
  late final Animation<double> _loaderFade;
  late final Animation<double> _progressValue;
  // Pulse ring
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  // Orbit
  late final Animation<double> _orbit;
  // Star twinkle
  late final Animation<double> _star;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
    _starCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();

    // Icon
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.00, 0.28, curve: Curves.easeOut)),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.00, 0.38, curve: Curves.elasticOut)),
    );

    // Title
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.32, 0.55, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.32, 0.55, curve: Curves.easeOutCubic)),
    );

    // Subtitle
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.48, 0.65, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.48, 0.65, curve: Curves.easeOutCubic)),
    );

    // Loader
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.60, 0.75, curve: Curves.easeOut)),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.62, 0.96, curve: Curves.easeInOut)),
    );

    // Pulse ring
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    // Orbit
    _orbit = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _orbitCtrl, curve: Curves.linear),
    );

    // Stars
    _star = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _starCtrl, curve: Curves.linear),
    );

    _mainCtrl.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    String? token;
    try {
      const secureStorage = FlutterSecureStorage();
      token = await secureStorage.read(key: ApiConstants.patStorageKey);
    } catch (_) {}
    final hasPat = token != null && token.isNotEmpty;
    final hasCompletedOnboarding = prefs.getBool('completed_onboarding') ?? false;

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, __, ___) =>
            (hasPat || hasCompletedOnboarding) ? const RootShell() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final scale = Tween<double>(begin: 1.05, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060414),
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _pulseCtrl, _orbitCtrl, _starCtrl]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Starfield background ───────────────────────────────────────
              CustomPaint(
                size: Size(size.width, size.height),
                painter: _StarfieldPainter(anim: _star),
              ),

              // ── Aurora top-left blob ───────────────────────────────────────
              Positioned(
                top: -size.width * 0.35,
                left: -size.width * 0.25,
                child: _GlowBlob(
                  diameter: size.width * 1.15,
                  color: const Color(0xFF7C3AED),
                  opacity: 0.18,
                ),
              ),

              // ── Aurora bottom-right blob ───────────────────────────────────
              Positioned(
                bottom: -size.width * 0.2,
                right: -size.width * 0.2,
                child: _GlowBlob(
                  diameter: size.width * 0.9,
                  color: const Color(0xFF2563EB),
                  opacity: 0.13,
                ),
              ),

              // ── Pink accent blob center-right ──────────────────────────────
              Positioned(
                top: size.height * 0.3,
                right: -size.width * 0.2,
                child: _GlowBlob(
                  diameter: size.width * 0.65,
                  color: const Color(0xFFDB2777),
                  opacity: 0.07,
                ),
              ),

              // ── Main content ───────────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Icon
                    FadeTransition(
                      opacity: _iconFade,
                      child: ScaleTransition(
                        scale: _iconScale,
                        child: SizedBox(
                          width: 186,
                          height: 186,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer pulse ring
                              Opacity(
                                opacity: _pulseOpacity.value,
                                child: Container(
                                  width: 150 * _pulseScale.value,
                                  height: 150 * _pulseScale.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),

                              // Deep glow halo
                              Container(
                                width: 152,
                                height: 152,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                      blurRadius: 90,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),

                              // Outer glass ring
                              Container(
                                width: 144,
                                height: 144,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.03),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              // App icon — perfectly circular, full bleed
                              ClipOval(
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  width: 128,
                                  height: 128,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              // Orbiting accent dot 1 — purple
                              Transform.translate(
                                offset: Offset(
                                  72 * cos(_orbit.value),
                                  72 * sin(_orbit.value),
                                ),
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFA78BFA),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFA78BFA).withValues(alpha: 0.85),
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Orbiting accent dot 2 — blue, opposite side
                              Transform.translate(
                                offset: Offset(
                                  72 * cos(_orbit.value + pi),
                                  72 * sin(_orbit.value + pi),
                                ),
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF60A5FA),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF60A5FA).withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 42),

                    // ── App Name ──────────────────────────────────────────────
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Git',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                                height: 1,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF818CF8), Color(0xFFC084FC)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: Text(
                                'Pulse',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  height: 1,
                                ),
                              ),
                            ),
                            Text(
                              '.',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFC084FC),
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Tagline ───────────────────────────────────────────────
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            'All GitHub Insights. One Powerful Pulse.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ── Progress ──────────────────────────────────────────────
                    FadeTransition(
                      opacity: _loaderFade,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 3,
                                    color: Colors.white.withValues(alpha: 0.07),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: _progressValue.value,
                                    child: Container(
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF818CF8), Color(0xFFC084FC)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Loading experience...',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.22),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Version label ─────────────────────────────────────────────
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: Center(
                    child: Text(
                      'V E R S I O N   1 . 0 . 0',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.15),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.5,
                      ),
                    ),
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

// ── Glow Blob ─────────────────────────────────────────────────────────────────

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.diameter,
    required this.color,
    required this.opacity,
  });
  final double diameter;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}

// ── Starfield Painter ─────────────────────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.anim}) : super(repaint: anim);
  final Animation<double> anim;

  static final List<_Star> _stars = _gen();
  static List<_Star> _gen() {
    final rng = Random(99);
    return List.generate(130, (_) => _Star(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      r: 0.4 + rng.nextDouble() * 1.3,
      base: 0.15 + rng.nextDouble() * 0.65,
      phase: rng.nextDouble() * 2 * pi,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final s in _stars) {
      final twinkle = 0.5 + 0.5 * sin(t * 2 * pi + s.phase);
      final alpha = (s.base * (0.5 + 0.5 * twinkle)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) => true;
}

class _Star {
  final double x, y, r, base, phase;
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.base,
    required this.phase,
  });
}
