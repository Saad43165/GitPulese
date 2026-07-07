import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class GlowingIndicator extends StatefulWidget {
  final double size;
  const GlowingIndicator({super.key, this.size = 40});

  @override
  State<GlowingIndicator> createState() => _GlowingIndicatorState();
}

class _GlowingIndicatorState extends State<GlowingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black87;
    
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer orbit
                Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.15),
                        width: widget.size * 0.05,
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: widget.size * 0.15,
                      height: widget.size * 0.15,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                // Inner orbit
                Transform.rotate(
                  angle: -_controller.value * 2 * math.pi,
                  child: Container(
                    width: widget.size * 0.5,
                    height: widget.size * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.1),
                        width: widget.size * 0.05,
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: widget.size * 0.1,
                      height: widget.size * 0.1,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                // Center dot
                Container(
                  width: widget.size * 0.1,
                  height: widget.size * 0.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
