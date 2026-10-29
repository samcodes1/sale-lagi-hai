import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';

final _now = DateTime.utc(2026, 10, 29, 12);

void main() {
  late DemoGateway demo;
  setUp(() => demo = DemoGateway(clock: () => _now));

  Future<List<String>> titles(
    String fn, [
    Map<String, Object?> p = const {},
  ]) async => [for (final r in await demo.rpc(fn, p)) r['title_en']! as String];

  test(
    'the demo rows have exactly the columns of the SQL deal_card type',
    () async {
      final sql = File('supabase/migrations/20261029140000_read_apis.sql')
          .readAsStringSync();
      final block = RegExp(r'create type public\.deal_card as \(([\s\S]*?)\);')
          .firstMatch(sql)!
          .group(1)!;
      final columns = {
        for (final m in RegExp(
          r'([a-z_]+)\s+[a-z_.\[\]]+',
          caseSensitive: false,
        ).allMatches(block))
          m.group(1)!,
      }..removeWhere((c) => c == 'public');
      final rows = await demo.rpc('feed', {'city_id': karachiId});
      expect(rows.first.keys.toSet(), columns);
    },
  );

  test('every demo row parses as a Deal', () async {
    for (final row in await demo.select(const TableQuery('deal_cards'))) {
      expect(() => dealFromRow(row), returnsNormally, reason: '${row['id']}');
    }
  });

  test('Karachi has every deal; other cities only nationwide/online', () async {
    expect(
      (await titles('feed', {'city_id': karachiId})).length,
      demoDeals.length,
    );
    final lahore = await demo.rpc('feed', {'city_id': lahoreId});
    expect(lahore.every((d) => d['scope'] != 'local'), isTrue);
    expect(lahore, isNotEmpty);
  });

  test('newest first, paged with a cursor without overlap', () async {
    final first = await demo.rpc('feed', {
      'city_id': karachiId,
      'page_size': 4,
    });
    final last = first.last;
    final second = await demo.rpc('feed', {
      'city_id': karachiId,
      'page_size': 4,
      'after_published_at': last['published_at'],
      'after_id': last['id'],
    });
    expect(
      first
          .map((d) => d['id'])
          .toSet()
          .intersection(second.map((d) => d['id']).toSet()),
      isEmpty,
    );
    final times = [
      ...first,
      ...second,
    ].map((d) => d['published_at']! as String).toList();
    expect(times, [...times]..sort((a, b) => b.compareTo(a)));
  });

  test('a parent category includes its subcategories', () async {
    final food = demoCategories.firstWhere(
      (c) => c['slug'] == 'food-and-restaurants',
    )['id'];
    final deals = await demo.rpc('feed', {
      'city_id': karachiId,
      'category_ids': [food],
    });
    expect(
      deals.map((d) => d['category_slug']).toSet(),
      containsAll(['bbq-and-karahi', 'fast-food', 'cafes-and-desserts']),
    );
  });

  test('following only shows followed brands', () async {
    expect(
      await demo.rpc('feed', {'city_id': karachiId, 'following_only': true}),
      isEmpty,
    );
    await demo.insert('follows', {
      'brand_id': brandBySlug('demo-threads')['id'],
    });
    expect(
      (await titles('feed', {
        'city_id': karachiId,
        'following_only': true,
      })).length,
      2,
    );
  });

  test(
    'featured: by priority, marked, city placements in their city',
    () async {
      final karachi = await demo.rpc('featured_deals', {
        'slot': 'home_featured',
        'city_id': karachiId,
      });
      expect(karachi.map((d) => d['title_en']), [
        'Family karahi for 4',
        'Winter collection sale',
      ]);
      expect(karachi.every((d) => d['is_featured'] == true), isTrue);
      final lahore = await demo.rpc('featured_deals', {
        'slot': 'home_featured',
        'city_id': lahoreId,
      });
      expect(lahore.map((d) => d['title_en']), ['Winter collection sale']);
    },
  );

  test(
    'nearby: within the radius, nearest first, with distances; no online deals',
    () async {
      final near = await demo.rpc('nearby_deals', {
        'lat': 24.8150,
        'lng': 67.0310,
        'radius_m': 1500,
      });
      expect(near.first['brand_slug'], 'demo-karahi-house');
      expect(near.first['distance_m'], lessThan(100));
      expect(near.every((d) => (d['distance_m']! as int) <= 1500), isTrue);
      expect(near.any((d) => d['scope'] == 'online'), isFalse);
    },
  );

  test("cards: only deals for the user's banks", () async {
    expect(
      await demo.rpc('deals_for_my_cards', {'city_id': karachiId}),
      isEmpty,
    );
    final hblCredit = demoCardProducts.firstWhere(
      (p) => p['bank_id'] == demoBanks.first['id'] && p['kind'] == 'credit',
    );
    await demo.insert('user_cards', {'card_product_id': hblCredit['id']});
    expect(await titles('deals_for_my_cards', {'city_id': karachiId}), [
      '20% off with HBL credit cards (demo)',
    ]);
  });

  test('search: words, typos and Urdu', () async {
    expect(
      await titles('search_deals', {'query': 'karahi', 'city_id': karachiId}),
      isNot(isEmpty),
    );
    expect(
      await titles('search_deals', {'query': 'burgr', 'city_id': karachiId}),
      contains('Two smash burgers for Rs 999'),
    );
    expect(
      await titles('search_deals', {'query': 'کڑاہی', 'city_id': karachiId}),
      contains('Family karahi for 4'),
    );
    expect(await demo.rpc('search_deals', {'query': 'b'}), isEmpty);
  });

  test('tables: filters, order and limit; writes need a match', () async {
    final live = await demo.select(
      const TableQuery('cities', equals: {'is_live': true}),
    );
    expect(live.single['slug'], 'karachi');
    final ordered = await demo.select(
      const TableQuery(
        'cities',
        orderBy: 'sort_order',
        ascending: false,
        limit: 2,
      ),
    );
    expect(
      ordered.first['sort_order'],
      greaterThan(ordered.last['sort_order']! as int),
    );
    await demo.insert('saves', {'deal_id': demoDeals.first.id});
    await demo.delete('saves', {'deal_id': demoDeals.first.id});
    expect(await demo.select(const TableQuery('saves')), isEmpty);
    expect(() => demo.delete('saves', {}), throwsArgumentError);
    expect(() => demo.insert('cities', {}), throwsUnsupportedError);
  });
}
