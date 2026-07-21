import 'package:flutter/material.dart';
import '../core/theme/app_spacing.dart';
import 'aurora_background.dart';

/// Height of the floating bottom nav pill (excluding system inset).
const kBottomNavReserve = 88.0;

/// Wraps tab screens with top safe area and bottom padding for the floating nav bar.
class SafePage extends StatelessWidget {
  const SafePage({
    super.key,
    required this.child,
    this.reserveBottomNav = false,
    this.useAurora = false,
  });

  final Widget child;
  final bool reserveBottomNav;
  final bool useAurora;

  @override
  Widget build(BuildContext context) {
    Widget page = SafeArea(
      bottom: !reserveBottomNav,
      child: child,
    );
    if (useAurora) {
      page = AuroraBackground(child: page);
    }
    return page;
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
