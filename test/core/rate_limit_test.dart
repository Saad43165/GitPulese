import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gitexplorer/core/network/dio_client.dart';

void main() {
  group('RateLimitInfo.fromHeaders', () {
    Headers makeHeaders(Map<String, String> map) {
      final response = Response(
        requestOptions: RequestOptions(path: '/'),
        headers: Headers.fromMap(map.map((k, v) => MapEntry(k, [v]))),
      );
      return response.headers;
    }

    test('returns null when headers are missing', () {
      final h = makeHeaders({});
      expect(RateLimitInfo.fromHeaders(h), isNull);
    });

    test('returns null when only some headers are present', () {
      final h = makeHeaders({'x-ratelimit-limit': '5000'});
      expect(RateLimitInfo.fromHeaders(h), isNull);
    });

    test('parses all three headers correctly', () {
      final resetEpoch = DateTime(2025, 1, 1, 12, 0, 0).millisecondsSinceEpoch ~/ 1000;
      final h = makeHeaders({
        'x-ratelimit-limit': '5000',
        'x-ratelimit-remaining': '4321',
        'x-ratelimit-reset': '$resetEpoch',
      });
      final info = RateLimitInfo.fromHeaders(h)!;
      expect(info.limit, 5000);
      expect(info.remaining, 4321);
      expect(info.resetAt.millisecondsSinceEpoch ~/ 1000, resetEpoch);
    });

    test('treats unparseable values as zero', () {
      final h = makeHeaders({
        'x-ratelimit-limit': 'bad',
        'x-ratelimit-remaining': 'bad',
        'x-ratelimit-reset': 'bad',
      });
      final info = RateLimitInfo.fromHeaders(h)!;
      expect(info.limit, 0);
      expect(info.remaining, 0);
    });
  });

  group('RateLimitNotifier', () {
    test('stream emits update and latest is stored', () async {
      final notifier = RateLimitNotifier.instance;
      final events = <RateLimitInfo>[];
      final sub = notifier.stream.listen(events.add);
      addTearDown(sub.cancel);

      final info = RateLimitInfo(
        limit: 5000,
        remaining: 4000,
        resetAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      notifier.update(info);
      await Future.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.last.remaining, 4000);
      expect(notifier.latest?.remaining, 4000);
    });

    test('broadcasts to multiple listeners', () async {
      final notifier = RateLimitNotifier.instance;
      final a = <RateLimitInfo>[];
      final b = <RateLimitInfo>[];

      final subA = notifier.stream.listen(a.add);
      final subB = notifier.stream.listen(b.add);
      addTearDown(() async {
        await subA.cancel();
        await subB.cancel();
      });

      notifier.update(RateLimitInfo(
        limit: 60,
        remaining: 59,
        resetAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a.last.remaining, 59);
      expect(b.last.remaining, 59);
    });

    test('cancelled subscription no longer receives events', () async {
      final notifier = RateLimitNotifier.instance;
      final int countBefore;
      final events = <RateLimitInfo>[];
      final sub = notifier.stream.listen(events.add);
      await sub.cancel();
      countBefore = events.length;

      notifier.update(RateLimitInfo(
        limit: 60,
        remaining: 1,
        resetAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(events.length, countBefore);
    });
  });
}
