import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import '../../core/constants/api_constants.dart';

/// Tracks the most recent rate-limit headers GitHub sent back, so the UI
/// can show a real, live "X requests remaining" indicator.
class RateLimitInfo {
  final int limit;
  final int remaining;
  final DateTime resetAt;

  const RateLimitInfo({
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  static RateLimitInfo? fromHeaders(Headers headers) {
    final limit = headers.value('x-ratelimit-limit');
    final remaining = headers.value('x-ratelimit-remaining');
    final reset = headers.value('x-ratelimit-reset');
    if (limit == null || remaining == null || reset == null) return null;

    return RateLimitInfo(
      limit: int.tryParse(limit) ?? 0,
      remaining: int.tryParse(remaining) ?? 0,
      resetAt: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(reset) ?? 0) * 1000,
      ),
    );
  }
}

class RateLimitNotifier {
  RateLimitNotifier._internal();
  static final RateLimitNotifier instance = RateLimitNotifier._internal();

  RateLimitInfo? _latest;
  final _listeners = <void Function(RateLimitInfo)>[];

  RateLimitInfo? get latest => _latest;

  void update(RateLimitInfo info) {
    _latest = info;
    for (final l in _listeners) {
      l(info);
    }
  }

  void addListener(void Function(RateLimitInfo) listener) =>
      _listeners.add(listener);
  void removeListener(void Function(RateLimitInfo) listener) =>
      _listeners.remove(listener);
}

class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConstants.backendBaseUrl}/github',
        connectTimeout: ApiConstants.requestTimeout,
        receiveTimeout: ApiConstants.requestTimeout,
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'GitExplorer-App',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final info = RateLimitInfo.fromHeaders(response.headers);
          if (info != null) RateLimitNotifier.instance.update(info);
          handler.next(response);
        },
        onError: (error, handler) {
          final headers = error.response?.headers;
          if (headers != null) {
            final info = RateLimitInfo.fromHeaders(headers);
            if (info != null) RateLimitNotifier.instance.update(info);
          }
          handler.next(error);
        },
      ),
    );

    // Global caching interceptor to save API quotas
    _dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(),
          policy: CachePolicy.request,
          hitCacheOnErrorCodes: const [],
          hitCacheOnNetworkFailure: true,
          maxStale: const Duration(hours: 1),
          priority: CachePriority.normal,
        ),
      ),
    );

    assert(() {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: false,
          responseBody: false,
          error: true,
          compact: true,
        ),
      );
      return true;
    }());
  }

  static final DioClient instance = DioClient._internal();
  late final Dio _dio;

  Dio get client => _dio;

  void applyPat(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }
}

/// A typed exception so the UI layer can show specific, real messages
/// instead of generic "something went wrong" mocks.
class GitHubApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;

  GitHubApiException(this.message, {this.statusCode, this.isRateLimited = false});

  @override
  String toString() => message;

  factory GitHubApiException.fromDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 403 || status == 429) {
      final remaining = e.response?.headers.value('x-ratelimit-remaining');
      if (remaining == '0') {
        final resetHeader = e.response?.headers.value('x-ratelimit-reset');
        final resetAt = resetHeader != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (int.tryParse(resetHeader) ?? 0) * 1000)
            : null;
        final resetStr = resetAt != null
            ? '${resetAt.hour.toString().padLeft(2, '0')}:${resetAt.minute.toString().padLeft(2, '0')}'
            : 'soon';
        return GitHubApiException(
          'GitHub rate limit reached. Resets at $resetStr. Add a free PAT in Settings for a higher limit.',
          statusCode: status,
          isRateLimited: true,
        );
      }
    }
    if (status == 404) {
      return GitHubApiException('Not found.', statusCode: status);
    }
    if (status == 422) {
      return GitHubApiException('Invalid search query.', statusCode: status);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return GitHubApiException('Request timed out. Check your connection.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return GitHubApiException('No internet connection.');
    }
    return GitHubApiException(
      e.response?.data is Map
          ? (e.response?.data['message'] as String? ?? 'Unexpected error.')
          : 'Unexpected error.',
      statusCode: status,
    );
  }
}
