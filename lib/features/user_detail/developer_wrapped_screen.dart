import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    int totalForks = widget.repos.fold(0, (sum, repo) => sum + repo.forksCount);
    
    final langCounts = <String, int>{};
    for (final r in widget.repos) {
      if (r.language != null) {
        langCounts[r.language!] = (langCounts[r.language!] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty ? sortedLangs.first.key : 'None';

    return Container(
      width: 350,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: AppColors.accent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'GitPulse',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Text(
                DateTime.now().year.toString(),
                style: TextStyle(
                  color: AppColors.accent.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Profile Pic
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFFE3B341)]),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.user.avatarUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            widget.user.name ?? widget.user.login,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '@${widget.user.login}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Stats Grid
          Row(
            children: [
              _buildStatBox('Total Stars', Formatters.compactNumber(totalStars), Icons.star_rounded, const Color(0xFFE3B341)),
              const SizedBox(width: 16),
              _buildStatBox('Followers', Formatters.compactNumber(widget.user.followers), Icons.people_alt_rounded, const Color(0xFF58A6FF)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBox('Top Lang', topLang, Icons.code_rounded, AppColors.colorForLanguage(topLang)),
              const SizedBox(width: 16),
              _buildStatBox('Public Repos', '${widget.user.publicRepos}', Icons.folder_rounded, const Color(0xFF3FB950)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
