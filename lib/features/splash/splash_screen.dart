import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../home/root_shell.dart';

class _OrbitPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _OrbitPainter(this.color, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw expanding orbits based on animation
    canvas.drawCircle(center, 60 + (animationValue * 40), paint);
    canvas.drawCircle(center, 120 + (animationValue * 60), paint);
    canvas.drawCircle(center, 180 + (animationValue * 80), paint);
    canvas.drawCircle(center, 240 + (animationValue * 100), paint);
    
    // Draw dots on orbits
    final dotPaint = Paint()..color = AppColors.accent;
    final angle = animationValue * 2 * math.pi;
    
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(angle) * (120 + (animationValue * 60)),
        center.dy + math.sin(angle) * (120 + (animationValue * 60)),
      ),
      4,
      dotPaint,
    );
    
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(-angle * 1.5) * (180 + (animationValue * 80)),
        center.dy + math.sin(-angle * 1.5) * (180 + (animationValue * 80)),
      ),
      6,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _orbit;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    
    _orbit = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const RootShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0D1117) : Colors.white;
    final orbitColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _OrbitPainter(orbitColor, _orbit.value),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.explore_rounded,
                            size: 64,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'GitPulse',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Discover the GitHub Universe',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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