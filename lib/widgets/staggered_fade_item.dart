import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Wraps a normal ListView.builder-style itemBuilder so every item fades
/// and slides in with a staggered delay on first build — a small but real
/// polish touch used across search results, dashboard rows, and history.
class StaggeredFadeItem extends StatelessWidget {
  const StaggeredFadeItem({
    super.key,
    required this.index,
    required this.child,
    this.horizontal = false,
  });

  final int index;
  final Widget child;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: horizontal
          ? SlideAnimation(
              horizontalOffset: 40,
              child: FadeInAnimation(child: child),
            )
          : SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(child: child),
            ),
    );
  }
}
