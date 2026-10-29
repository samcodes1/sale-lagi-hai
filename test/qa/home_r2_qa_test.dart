// QA, sub-phase 4.3 round 2: the cache pruning added for BUG-4
// (`JsonCache.prune`, run at startup by bootstrap) (docs/qa/4.3.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';

import '../helpers/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);

  test('prune removes old and unreadable home copies only', () async {
    final store = InMemoryKeyValueStore();
    var clock = now.subtract(const Duration(days: 10));
    final cache = JsonCache(store, clock: () => clock);
    await cache.put('home.trending.old', [1]);
    await cache.put('search.recent', ['karahi']); // not a home copy
    clock = now.subtract(const Duration(hours: 1));
    await cache.put('home.trending.fresh', [2]);
    await store.setString('cache.home.foryou.broken', '{not json');
    await store.setString('settings.locale', 'ur'); // not a cache entry
    clock = now;
    await cache.prune('home.', maxAge: homeCacheMaxAge);
    expect(store.values.keys.toSet(), {
      'cache.search.recent',
      'cache.home.trending.fresh',
      'settings.locale',
    });
  });

  test('a copy saved "in the future" (clock moved back) is kept, not '
      'deleted, and not shown', () async {
    final store = InMemoryKeyValueStore();
    var clock = now.add(const Duration(days: 1));
    final cache = JsonCache(store, clock: () => clock);
    await cache.put('home.trending.x', [1]);
    clock = now;
    await cache.prune('home.', maxAge: homeCacheMaxAge);
    expect(store.values.keys, contains('cache.home.trending.x'));
    expect(await cache.get('home.trending.x', maxAge: homeCacheMaxAge), isNull);
  });

  test('prune never throws, even when the store does', () async {
    final cache = JsonCache(_BrokenKeys());
    await cache.prune('home.', maxAge: homeCacheMaxAge);
  });
}

final class _BrokenKeys implements KeyValueStore {
  @override
  Future<Set<String>> keys() => throw StateError('io');

  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}
}
