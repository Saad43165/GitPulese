import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

/// A single shimmer block — use it to build skeleton layouts.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12.0,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shimmer wrapper — wraps any skeleton layout in the animated shimmer effect.
class ShimmerWrapper extends StatelessWidget {
  const ShimmerWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSurface : const Color(0xFFE2E8F0),
      highlightColor: isDark ? AppColors.darkBorder : const Color(0xFFF8FAFC),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

// ── Specific skeleton shapes ───────────────────────────────────────────────────

/// Skeleton for a horizontal repo card (trending row).
class ShimmerRepoCard extends StatelessWidget {
  const ShimmerRepoCard({super.key, this.width = 220});
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerWrapper(
      child: Container(
        width: width,
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 28, height: 28, radius: 7),
                const SizedBox(width: 8),
                ShimmerBox(width: width * 0.45, height: 11, radius: 6),
              ],
            ),
            const SizedBox(height: 8),
            const ShimmerBox(width: double.infinity, height: 9, radius: 6),
            const SizedBox(height: 5),
            ShimmerBox(width: width * 0.55, height: 9, radius: 6),
            const SizedBox(height: 8),
            const Row(
              children: [
                ShimmerBox(width: 36, height: 9, radius: 6),
                SizedBox(width: 8),
                ShimmerBox(width: 36, height: 9, radius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a vertical repo list card (search results / history).
class ShimmerListCard extends StatelessWidget {
  const ShimmerListCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 40, height: 40, radius: 10),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: double.infinity, height: 12, radius: 6),
                      SizedBox(height: 6),
                      ShimmerBox(width: 120, height: 10, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ShimmerBox(width: double.infinity, height: 10, radius: 6),
            SizedBox(height: 6),
            ShimmerBox(width: 200, height: 10, radius: 6),
            SizedBox(height: 12),
            Row(
              children: [
                ShimmerBox(width: 50, height: 10, radius: 6),
                SizedBox(width: 12),
                ShimmerBox(width: 50, height: 10, radius: 6),
                SizedBox(width: 12),
                ShimmerBox(width: 60, height: 10, radius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a developer avatar card (top users row).
class ShimmerDeveloperCard extends StatelessWidget {
  const ShimmerDeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerWrapper(
      child: Container(
        width: 100,
        height: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerBox(width: 56, height: 56, radius: 28),
            SizedBox(height: 10),
            ShimmerBox(width: 60, height: 10, radius: 6),
            SizedBox(height: 6),
            ShimmerBox(width: 44, height: 8, radius: 6),
          ],
        ),
      ),
    );
  }
}

class ShimmerListCards extends StatelessWidget {
  const ShimmerListCards({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: count,
      itemBuilder: (context, index) => const ShimmerListCard(),
    );
  }
}

// ── Full-page skeletons ────────────────────────────────────────────────────────

/// Full-page skeleton for RepoDetailScreen while the repo is loading.
class ShimmerRepoDetailPage extends StatelessWidget {
  const ShimmerRepoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              color: isDark ? AppColors.darkBg : Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Row(
                    children: [
                      ShimmerBox(width: 28, height: 28, radius: 14),
                      SizedBox(width: 10),
                      ShimmerBox(width: 100, height: 12, radius: 6),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const ShimmerBox(width: 220, height: 18, radius: 6),
                  const SizedBox(height: 8),
                  ShimmerBox(width: w * 0.7, height: 12, radius: 6),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  ShimmerBox(width: 70, height: 32, radius: 16),
                  SizedBox(width: 10),
                  ShimmerBox(width: 70, height: 32, radius: 16),
                  SizedBox(width: 10),
                  ShimmerBox(width: 70, height: 32, radius: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ShimmerBox(width: 140, height: 14, radius: 6),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                ShimmerListCard(),
                ShimmerListCard(),
                ShimmerListCard(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton for UserDetailScreen while profile is loading.
class ShimmerUserDetailPage extends StatelessWidget {
  const ShimmerUserDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              height: 260,
              color: isDark ? AppColors.darkBg : Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 50),
                  ShimmerBox(width: 100, height: 100, radius: 50),
                  SizedBox(height: 14),
                  ShimmerBox(width: 140, height: 16, radius: 8),
                  SizedBox(height: 8),
                  ShimmerBox(width: 90, height: 12, radius: 6),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const ShimmerBox(width: double.infinity, height: 12, radius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: w * 0.65, height: 12, radius: 6),
              ]),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ShimmerBox(width: 60, height: 36, radius: 8),
                    ShimmerBox(width: 60, height: 36, radius: 8),
                    ShimmerBox(width: 60, height: 36, radius: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                ShimmerListCard(),
                ShimmerListCard(),
                ShimmerListCard(),
                ShimmerListCard(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
