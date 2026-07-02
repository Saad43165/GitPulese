import 'package:flutter/material.dart';
import '../core/theme/app_spacing.dart';

/// Height of the floating bottom nav pill (excluding system inset).
const kBottomNavReserve = 88.0;

/// Wraps tab screens with top safe area and bottom padding for the floating nav bar.
class SafePage extends StatelessWidget {
  const SafePage({
    super.key,
    required this.child,
    this.reserveBottomNav = true,
  });

  final Widget child;
  final bool reserveBottomNav;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navReserve = reserveBottomNav ? kBottomNavReserve + bottomInset : 0.0;

    return SafeArea(
      bottom: false,
      child: child,
    );
  }
}

/// Standard horizontal page padding.
EdgeInsets pagePadding({double bottom = AppSpacing.pageBottom}) {
  return EdgeInsets.fromLTRB(
    AppSpacing.pageHorizontal,
    0,
    AppSpacing.pageHorizontal,
    bottom,
  );
}