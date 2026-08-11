import 'package:flutter/material.dart';

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.master,
    this.detail,
    this.breakpoint = 800.0,
    this.masterFlex = 2,
    this.detailFlex = 3,
  });

  final Widget master;
  final Widget? detail;
  final double breakpoint;
  final int masterFlex;
  final int detailFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= breakpoint;

        if (isWideScreen && detail != null) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Row(
            children: [
              Expanded(
                flex: masterFlex,
                child: master,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                flex: detailFlex,
                child: detail!,
              ),
            ],
          );
        }

        return master;
      },
    );
  }
}
