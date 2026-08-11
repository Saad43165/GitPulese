import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_providers.dart';

class AuroraBackground extends ConsumerStatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPerformanceMode = ref.watch(performanceModeProvider);
    
    // Soothing Obsidian & Polar Ice Base Colors
    final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);

    if (isPerformanceMode) {
      // Ultra-fast hardware-accelerated static background for budget/low-end devices
      return Scaffold(
        backgroundColor: bgColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.6, -0.6),
              radius: 1.2,
              colors: isDark
                  ? [
                      const Color(0xFF1E1B4B).withValues(alpha: 0.35),
                      const Color(0xFF090D16),
                    ]
                  : [
                      const Color(0xFFE0E7FF).withValues(alpha: 0.6),
                      const Color(0xFFF8FAFC),
                    ],
            ),
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      );
    }
    
    // Violet and Blue glows
    final orb1Color = isDark 
        ? const Color(0xFF6366F1).withValues(alpha: 0.12) 
        : const Color(0xFFA5B4FC).withValues(alpha: 0.18);
        
    final orb2Color = isDark 
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.10) 
        : const Color(0xFFC084FC).withValues(alpha: 0.14);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Orbs wrapped in RepaintBoundary to prevent list scroll repaints
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.08 + sin(_controller.value * 2 * pi) * 45,
                      left: MediaQuery.of(context).size.width * 0.15 + cos(_controller.value * 2 * pi) * 35,
                      child: _buildOrb(orb1Color, 320),
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.08 + cos(_controller.value * 2 * pi) * 45,
                      right: MediaQuery.of(context).size.width * 0.1 + sin(_controller.value * 2 * pi) * 35,
                      child: _buildOrb(orb2Color, 360),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Optimized Blur Layer (Frosted Glass)
          Positioned.fill(
            child: RepaintBoundary(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Main Content
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
