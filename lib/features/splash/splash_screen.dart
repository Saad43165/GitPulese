import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/root_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;

  late final Animation<double> _logoBg;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _progressFade;
  late final Animation<double> _progressValue;
  late final Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _waveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 1.0, curve: Curves.linear)),
    );

    _logoBg = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.25, curve: Curves.easeOut)),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.05, 0.4, curve: Curves.elasticOut)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.05, 0.3, curve: Curves.easeOut)),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.30, 0.55, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.30, 0.55, curve: Curves.easeOutCubic)),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.45, 0.65, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.45, 0.65, curve: Curves.easeOutCubic)),
    );

    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.55, 0.70, curve: Curves.easeOut)),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.55, 0.92, curve: Curves.easeInOut)),
    );

    _mainCtrl.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const RootShell(),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final scale = Tween<double>(begin: 1.04, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _mainCtrl,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background wave mesh
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.30,
                child: CustomPaint(
                  painter: _WaveMeshPainter(animation: _waveAnim),
                ),
              ),

              // Center content — staggered entry
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Logo icon with glow halo ──
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: _logoBg.value,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF8B5CF6).withValues(alpha: 0.5 * _logoBg.value),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Title ──
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
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF60A5FA), Color(0xFF9333EA)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds),
                                child: Text(
                                  'Pulse',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 46,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Subtitle ──
                      FadeTransition(
                        opacity: _subtitleFade,
                        child: SlideTransition(
                          position: _subtitleSlide,
                          child: Text(
                            'All GitHub Insights. One Powerful Pulse.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Progress bar ──
                      FadeTransition(
                        opacity: _progressFade,
                        child: SizedBox(
                          width: 120,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progressValue.value,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                            ),
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

// ─── Wave Mesh Painter ────────────────────────────────────────────────────────

class _WaveMeshPainter extends CustomPainter {
  _WaveMeshPainter({required this.animation}) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF6B21A8).withValues(alpha: 0.12),
          const Color(0xFF4C1D95).withValues(alpha: 0.35),
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int i = 0; i < 7; i++) {
      final path = Path();
      final offset = (animation.value * size.width * 0.5) + (i * 25.0);
      path.moveTo(0, size.height * 0.5);

      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height * 0.5
            + sin((x + offset) * 0.016 + i * 0.7) * 10.0 * (1.0 + 0.08 * i)
            + cos((x - offset * 0.6) * 0.011) * 6.0;
        path.lineTo(x, y);
      }

      wavePaint.color = const Color(0xFF8B5CF6).withValues(alpha: 0.08 + (i * 0.018));
      canvas.drawPath(path, wavePaint);
    }

    final spikePaint = Paint()..strokeWidth = 0.8;
    const spikeCount = 22;
    final spacing = size.width / (spikeCount + 1);

    for (int i = 0; i < spikeCount; i++) {
      final x = spacing * (i + 1);
      final maxH = 12.0 + 10.0 * sin(i * pi / (spikeCount / 2));
      final currentH = maxH * (0.55 + 0.45 * sin(animation.value * pi * 3 + i * 0.6));
      final base = size.height * 0.5 + sin((x + animation.value * size.width * 0.5) * 0.016) * 10.0;

      spikePaint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF9333EA).withValues(alpha: 0.7),
          const Color(0xFFC084FC).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(x, base - currentH, 1.0, currentH));

      canvas.drawLine(Offset(x, base), Offset(x, base - currentH), spikePaint);

      canvas.drawCircle(
        Offset(x, base - currentH),
        1.2,
        Paint()..color = const Color(0xFFE879F9).withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveMeshPainter oldDelegate) => true;
}
