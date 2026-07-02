import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ExpandableSection extends StatefulWidget {
  final Widget child;
  final double collapsedHeight;
  final String expandText;
  final String collapseText;

  const ExpandableSection({
    super.key,
    required this.child,
    this.collapsedHeight = 200.0,
    this.expandText = 'Read more',
    this.collapseText = 'Show less',
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: _expanded
                ? const BoxConstraints()
                : BoxConstraints(maxHeight: widget.collapsedHeight),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: widget.child,
                ),
                if (!_expanded)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.0),
                            (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            _expanded ? widget.collapseText : widget.expandText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
