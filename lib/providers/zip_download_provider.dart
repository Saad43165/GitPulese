import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ZipDownloadState {
  final bool isDownloading;
  final double progress; // -1.0 indicates indeterminate (total size unknown)
  final String? repoName;
  final String? error;
  final String? path;
  final bool isCancelled;
  final String? speed;
  final String? sizeInfo;

  ZipDownloadState({
    required this.isDownloading,
    required this.progress,
    this.repoName,
    this.error,
    this.path,
    this.isCancelled = false,
    this.speed,
    this.sizeInfo,
  });

  ZipDownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? repoName,
    String? error,
    String? path,
    bool? isCancelled,
    String? speed,
    String? sizeInfo,
  }) {
    return ZipDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      repoName: repoName ?? this.repoName,
      error: error ?? this.error,
      path: path ?? this.path,
      isCancelled: isCancelled ?? this.isCancelled,
      speed: speed ?? this.speed,
      sizeInfo: sizeInfo ?? this.sizeInfo,
    );
  }
}

class ZipDownloadNotifier extends StateNotifier<ZipDownloadState> {
  ZipDownloadNotifier() : super(ZipDownloadState(isDownloading: false, progress: 0.0));

  CancelToken? _cancelToken;

  Future<void> startDownload({
    required String owner,
    required String repoName,
    String? branch,
    String? token,
  }) async {
    if (state.isDownloading) return;

    state = ZipDownloadState(
      isDownloading: true,
      progress: -1.0, // Indeterminate initially
      repoName: repoName,
      speed: '0 KB/s',
      sizeInfo: 'Connecting...',
    );

    _cancelToken = CancelToken();

    try {
      // Use official GitHub API zipball URL. If branch is omitted, GitHub automatically uses default branch (main/master).
      final zipUrl = (branch != null && branch.isNotEmpty)
          ? 'https://api.github.com/repos/$owner/$repoName/zipball/$branch'
          : 'https://api.github.com/repos/$owner/$repoName/zipball';

      final tempDir = await getTemporaryDirectory();
      final suffix = (branch != null && branch.isNotEmpty) ? '-$branch' : '';
      final savePath = '${tempDir.path}/$repoName$suffix.zip';

      final startTime = DateTime.now();

      final dio = Dio();
      
      // Inject user's GitHub Personal Access Token if available to handle private repos and higher rate limits
      final headers = {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'GitPulse-App',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      await dio.download(
        zipUrl,
        savePath,
        cancelToken: _cancelToken,
        options: Options(headers: headers),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsedMs = now.difference(startTime).inMilliseconds;
          
          String speedStr = '0 KB/s';
          if (elapsedMs > 100) {
            final speedBytesPerSec = (received / elapsedMs) * 1000;
            if (speedBytesPerSec > 1024 * 1024) {
              speedStr = '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              speedStr = '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
            }
          }

          String sizeInfoStr = '';
          if (total != -1 && total > 0) {
            final receivedMB = received / (1024 * 1024);
            final totalMB = total / (1024 * 1024);
            sizeInfoStr = '${receivedMB.toStringAsFixed(1)}MB / ${totalMB.toStringAsFixed(1)}MB';
          } else {
            final receivedMB = received / (1024 * 1024);
            sizeInfoStr = '${receivedMB.toStringAsFixed(1)}MB downloaded';
          }

          state = state.copyWith(
            progress: (total != -1 && total > 0) ? (received / total).clamp(0.0, 1.0) : -1.0,
            speed: speedStr,
            sizeInfo: sizeInfoStr,
          );
        },
      );

      state = state.copyWith(
        isDownloading: false,
        path: savePath,
        progress: 1.0,
      );

      // Trigger share sheet
      await Share.shareXFiles([XFile(savePath)], text: '$repoName Source Code');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = ZipDownloadState(isDownloading: false, progress: 0.0, isCancelled: true);
      } else {
        String errMsg = e.message ?? 'Download failed';
        if (e.response?.statusCode == 404) {
          errMsg = 'Repository branch not found (404).';
        }
        state = ZipDownloadState(
          isDownloading: false,
          progress: 0.0,
          error: errMsg,
        );
      }
    } catch (e) {
      state = ZipDownloadState(
        isDownloading: false,
        progress: 0.0,
        error: e.toString(),
      );
    }
  }

  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled');
      state = ZipDownloadState(isDownloading: false, progress: 0.0, isCancelled: true);
    }
  }

  void clearState() {
    state = ZipDownloadState(isDownloading: false, progress: 0.0);
  }
}

final zipDownloadProvider = StateNotifierProvider<ZipDownloadNotifier, ZipDownloadState>((ref) {
  return ZipDownloadNotifier();
});
