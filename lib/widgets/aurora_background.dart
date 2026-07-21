import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
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
    
    // Aurora Core Colors
    final bgColor = isDark ? const Color(0xFF030305) : const Color(0xFFF8FAFC);
    
    // Violet and Blue glows
    final orb1Color = isDark 
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15) 
        : const Color(0xFFC084FC).withValues(alpha: 0.2);
        
    final orb2Color = isDark 
        ? const Color(0xFF3B82F6).withValues(alpha: 0.12) 
        : const Color(0xFF60A5FA).withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Orbs
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.1 + sin(_controller.value * 2 * pi) * 60,
                    left: MediaQuery.of(context).size.width * 0.2 + cos(_controller.value * 2 * pi) * 40,
                    child: _buildOrb(orb1Color, 350),
                  ),
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.1 + cos(_controller.value * 2 * pi) * 60,
                    right: MediaQuery.of(context).size.width * 0.1 + sin(_controller.value * 2 * pi) * 40,
                    child: _buildOrb(orb2Color, 400),
                  ),
                ],
              );
            },
          ),
          
          // Heavy Blur Layer (Frosted Glass)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // Main Content
          widget.child,
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
