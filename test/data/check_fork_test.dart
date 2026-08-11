import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gitexplorer/data/remote/github_api_service.dart';

/// Minimal stub Interceptor that returns preset responses without touching the network.
class _FakeInterceptor extends Interceptor {
  final Map<String, dynamic> _routes;

  _FakeInterceptor(this._routes);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.path;
    if (_routes.containsKey(key)) {
      final body = _routes[key];
      if (body == null) {
        // Simulate 404
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: {'message': 'Not Found'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        return;
      }
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: body,
        ),
      );
    } else {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'No stub for ${options.path}',
        ),
      );
    }
  }
}

GitHubApiService _serviceWith(Map<String, dynamic> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
  dio.interceptors.add(_FakeInterceptor(routes));
  return GitHubApiService(dio);
}

void main() {
  group('GitHubApiService.checkFork', () {
    test('returns true when the user has a fork of the given repo', () async {
      final service = _serviceWith({
        '/user': {'login': 'alice'},
        '/repos/alice/my-lib': {
          'fork': true,
          'parent': {'full_name': 'bob/my-lib'},
        },
      });
      expect(await service.checkFork('bob', 'my-lib'), isTrue);
    });

    test('returns false when the repo exists but is not a fork', () async {
      final service = _serviceWith({
        '/user': {'login': 'alice'},
        '/repos/alice/my-lib': {
          'fork': false,
          'parent': null,
        },
      });
      expect(await service.checkFork('bob', 'my-lib'), isFalse);
    });

    test('returns false when the fork parent does not match', () async {
      final service = _serviceWith({
        '/user': {'login': 'alice'},
        '/repos/alice/my-lib': {
          'fork': true,
          'parent': {'full_name': 'carol/other-lib'},
        },
      });
      expect(await service.checkFork('bob', 'my-lib'), isFalse);
    });

    test('returns false when the user does not have that repo (404)', () async {
      final service = _serviceWith({
        '/user': {'login': 'alice'},
        '/repos/alice/my-lib': null, // triggers 404
      });
      expect(await service.checkFork('bob', 'my-lib'), isFalse);
    });

    test('skips /user call when authLogin is provided', () async {
      // No /user stub — if it were called, the test would throw
      final service = _serviceWith({
        '/repos/alice/my-lib': {
          'fork': true,
          'parent': {'full_name': 'bob/my-lib'},
        },
      });
      expect(
        await service.checkFork('bob', 'my-lib', authLogin: 'alice'),
        isTrue,
      );
    });
  });
}
