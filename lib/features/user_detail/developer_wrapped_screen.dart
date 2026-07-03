import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_and_search_models.dart';
import '../../../data/models/repo_model.dart';
import '../../../core/utils/formatters.dart';

class DeveloperWrappedScreen extends StatefulWidget {
  final GhUser user;
  final List<GhRepo> repos;

  const DeveloperWrappedScreen({super.key, required this.user, required this.repos});

  @override
  State<DeveloperWrappedScreen> createState() => _DeveloperWrappedScreenState();
}

class _DeveloperWrappedScreenState extends State<DeveloperWrappedScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  Future<void> _shareCard() async {
    setState(() => _isCapturing = true);
    try {
      final image = await _screenshotController.capture(pixelRatio: 3.0);
      if (image == null) return;
      
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/${widget.user.login}_wrapped.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)], 
        text: 'Check out ${widget.user.name ?? widget.user.login}\'s GitHub Stats on GitPulse! 🚀🔥',
      );
      
      // Request App Review after sharing
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Card'),
        actions: [
          if (!_isCapturing)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _shareCard,
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: _buildCard(context),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isCapturing ? null : _shareCard,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share to Socials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    int totalStars = widget.repos.fold(0, (sum, repo) => sum + repo.stargazersCount);
    
    final langCounts = <String, int>{};
    for (final r in widget.repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';

    return Container(
      width: 380,
      height: 560,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.colorForLanguage(topLang).withValues(alpha: 0.3),
            const Color(0xFF0F172A),
            const Color(0xFF1E1B4B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          )
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Holographic foil effect
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/noise.png', // Assuming we have noise or we can just use a gradient
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: SweepGradient(
                        colors: [Colors.purple, Colors.blue, Colors.green, Colors.yellow, Colors.red, Colors.purple],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Inner border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Header (Type / Class)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.colorForLanguage(topLang), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ELITE DEV',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.colorForLanguage(topLang),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LVL ${math.min(99, (totalStars / 50).ceil() + (widget.user.followers / 20).ceil())}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                
                // Avatar (Centerpiece)
                Container(
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.colorForLanguage(topLang), Colors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.colorForLanguage(topLang).withValues(alpha: 0.6),
                        blurRadius: 30,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.user.avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Name & Title
                Text(
                  widget.user.name ?? widget.user.login,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${widget.user.login} • $topLang Master',
                  style: TextStyle(
                    color: AppColors.colorForLanguage(topLang),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(formatCount(totalStars), 'STARS', Icons.star_rounded),
                      _buildMiniStat(formatCount(widget.user.followers), 'FANS', Icons.people_alt_rounded),
                      _buildMiniStat('${widget.user.publicRepos}', 'REPOS', Icons.folder_rounded),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hub_rounded, color: Colors.white54, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Generated by GitPulse',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ],
    );
  }
}
