import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zip_download_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_spacing.dart';

class GlobalZipProgressOverlay extends ConsumerStatefulWidget {
  const GlobalZipProgressOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GlobalZipProgressOverlay> createState() => _GlobalZipProgressOverlayState();
}

class _GlobalZipProgressOverlayState extends ConsumerState<GlobalZipProgressOverlay> {
  String? _currentDownloadingRepo;
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(zipDownloadProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    final isIndeterminate = downloadState.progress < 0;

    // Monitor download state changes to reset dismissal state
    if (downloadState.isDownloading) {
      if (_currentDownloadingRepo != downloadState.repoName) {
        _currentDownloadingRepo = downloadState.repoName;
        _isDismissed = false;
      }
    } else {
      _currentDownloadingRepo = null;
      _isDismissed = false;
    }

    // Build the step-based progress line for the banner
    final stepCount = isIndeterminate ? 0 : (downloadState.progress * 10).clamp(0, 10).toInt();
    final filledSteps = '■' * stepCount;
    final emptySteps = '□' * (10 - stepCount);
    final progressVisual = isIndeterminate ? '[Streaming ZIP...]' : '[$filledSteps$emptySteps]';

    return Stack(
      children: [
        widget.child,
        
        // 1. Browser-style thin loading indicator at the absolute top of the screen
        if (downloadState.isDownloading)
          Positioned(
            top: paddingTop,
            left: 0,
            right: 0,
            height: 3,
            child: IgnorePointer(
              child: LinearProgressIndicator(
                value: isIndeterminate ? null : downloadState.progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),

        // 2. Rich Floating Banner (Dismissible by swiping horizontal)
        if (downloadState.isDownloading && !_isDismissed)
          Positioned(
            top: paddingTop + 12,
            left: 16,
            right: 16,
            child: Dismissible(
              key: Key(downloadState.repoName ?? 'download_zip_key'),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                setState(() {
                  _isDismissed = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Minimized. Tap the floating icon to restore.'),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 80, left: 16, right: 16), // Position near top so it's not blocked by bottom navbar
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xEE161B22) 
                        : const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.downloading_rounded, 
                            color: AppColors.accent, 
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Downloading ${downloadState.repoName ?? 'repository'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${downloadState.sizeInfo ?? "Connecting..."} • ${downloadState.speed ?? "0 KB/s"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(zipDownloadProvider.notifier).cancelDownload();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: isIndeterminate ? null : downloadState.progress,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            progressVisual,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.accent,
                            ),
                          ),
                          const Row(
                            children: [
                              Icon(Icons.swipe_rounded, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Swipe to minimize',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 3. Floating Restore Button (Visible only when download is active AND user swiped it away)
        if (downloadState.isDownloading && _isDismissed)
          Positioned(
            bottom: 80, // Floats safely above the bottom navigation bar
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: FloatingActionButton.small(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isDismissed = false;
                    });
                  },
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.downloading_rounded),
                ),
              ),
            ),
          ),
        
        // Show status message for Cancel or Error
        if (downloadState.error != null || downloadState.isCancelled)
          Positioned(
            top: paddingTop + 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * -20),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, 
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: downloadState.error != null 
                        ? AppColors.danger.withValues(alpha: 0.9) 
                        : Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        downloadState.error != null 
                            ? Icons.error_outline_rounded 
                            : Icons.cancel_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          downloadState.error ?? 'Download cancelled.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        onPressed: () {
                          ref.read(zipDownloadProvider.notifier).clearState();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
