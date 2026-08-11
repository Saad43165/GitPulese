import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitexplorer/features/discovery/discovery_screen.dart';

void main() {
  group('discoveryCategoryProvider', () {
    test('defaults to "For You"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(discoveryCategoryProvider), 'For You');
    });

    test('can be changed to any category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(discoveryCategoryProvider.notifier).state = 'Flutter';
      expect(container.read(discoveryCategoryProvider), 'Flutter');

      container.read(discoveryCategoryProvider.notifier).state = 'Rust';
      expect(container.read(discoveryCategoryProvider), 'Rust');
    });
  });

  group('language ranking logic', () {
    // Mirrors the ranking logic inside _userTopLanguagesProvider
    List<String> topLanguages(List<String?> langs, {int take = 3}) {
      final counts = <String, int>{};
      for (final lang in langs) {
        if (lang != null && lang.isNotEmpty) counts[lang] = (counts[lang] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(take).map((e) => e.key).toList();
    }

    test('returns empty list when all langs are null', () {
      expect(topLanguages([null, null]), isEmpty);
    });

    test('returns top language by frequency', () {
      final langs = ['Dart', 'Dart', 'Dart', 'Python', 'Python', 'Go'];
      expect(topLanguages(langs).first, 'Dart');
    });

    test('limits result to top 3', () {
      final langs = ['Dart', 'Python', 'Go', 'Rust', 'TypeScript'];
      expect(topLanguages(langs).length, lessThanOrEqualTo(3));
    });

    test('skips empty string languages', () {
      expect(topLanguages(['', '', null, 'Dart']).first, 'Dart');
    });

    test('preserves frequency ranking order', () {
      final langs = ['Go', 'Dart', 'Dart', 'Go', 'Go', 'Python'];
      final result = topLanguages(langs);
      expect(result[0], 'Go');
      expect(result[1], 'Dart');
      expect(result[2], 'Python');
    });
  });
}
