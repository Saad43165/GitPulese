import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300],
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
      baseColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey[100]!,
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
    return ShimmerWrapper(
      child: Container(
        width: width,
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ShimmerBox(width: 28, height: 28, radius: 7),
                const SizedBox(width: 8),
                ShimmerBox(width: width * 0.45, height: 11, radius: 6),
              ],
            ),
            const SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 9, radius: 6),
            const SizedBox(height: 5),
            ShimmerBox(width: width * 0.55, height: 9, radius: 6),
            const SizedBox(height: 8),
            Row(
              children: [
                const ShimmerBox(width: 36, height: 9, radius: 6),
                const SizedBox(width: 8),
                const ShimmerBox(width: 36, height: 9, radius: 6),
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
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 40, height: 40, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: double.infinity, height: 12, radius: 6),
                      const SizedBox(height: 6),
                      const ShimmerBox(width: 120, height: 10, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShimmerBox(width: double.infinity, height: 10, radius: 6),
            const SizedBox(height: 6),
            const ShimmerBox(width: 200, height: 10, radius: 6),
            const SizedBox(height: 12),
            Row(
              children: [
                const ShimmerBox(width: 50, height: 10, radius: 6),
                const SizedBox(width: 12),
                const ShimmerBox(width: 50, height: 10, radius: 6),
                const SizedBox(width: 12),
                const ShimmerBox(width: 60, height: 10, radius: 6),
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
    return ShimmerWrapper(
      child: Container(
        width: 100,
        height: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ShimmerBox(width: 56, height: 56, radius: 28),
            const SizedBox(height: 10),
            ShimmerBox(width: 60, height: 10, radius: 6),
            const SizedBox(height: 6),
            ShimmerBox(width: 44, height: 8, radius: 6),
          ],
        ),
      ),
    );
  }
}

/// A shimmer list of [count] vertical cards, for search/history loading.
class ShimmerListCards extends StatelessWidget {
  const ShimmerListCards({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(count, (_) => const ShimmerListCard()),
      ),
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
            // Fake SliverAppBar header area
            Container(
              height: 200,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Owner row
                  Row(
                    children: [
                      ShimmerBox(width: 28, height: 28, radius: 14),
                      const SizedBox(width: 10),
                      const ShimmerBox(width: 100, height: 12, radius: 6),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const ShimmerBox(width: 220, height: 18, radius: 6),
                  const SizedBox(height: 8),
                  ShimmerBox(width: w * 0.7, height: 12, radius: 6),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const ShimmerBox(width: 70, height: 32, radius: 16),
                  const SizedBox(width: 10),
                  const ShimmerBox(width: 70, height: 32, radius: 16),
                  const SizedBox(width: 10),
                  const ShimmerBox(width: 70, height: 32, radius: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Section title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ShimmerBox(width: 140, height: 14, radius: 6),
            ),
            const SizedBox(height: 12),
            // Fake cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                const ShimmerListCard(),
                const ShimmerListCard(),
                const ShimmerListCard(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton for UserDetailScreen while the user profile is loading.
class ShimmerUserDetailPage extends StatelessWidget {
  const ShimmerUserDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Fake hero header
            Container(
              height: 280,
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Avatar circle
                  ShimmerBox(width: 110, height: 110, radius: 55),
                  const SizedBox(height: 14),
                  const ShimmerBox(width: 140, height: 16, radius: 8),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 90, height: 12, radius: 6),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bio lines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                ShimmerBox(width: double.infinity, height: 12, radius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: w * 0.65, height: 12, radius: 6),
              ]),
            ),
            const SizedBox(height: 20),
            // Stats box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const ShimmerBox(width: 60, height: 36, radius: 8),
                    const ShimmerBox(width: 60, height: 36, radius: 8),
                    const ShimmerBox(width: 60, height: 36, radius: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Fake repo cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const ShimmerListCard(),
                const ShimmerListCard(),
                const ShimmerListCard(),
                const ShimmerListCard(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

