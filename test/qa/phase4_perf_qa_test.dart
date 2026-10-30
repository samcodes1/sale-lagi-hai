// QA, Phase 4 gate: performance sanity on the real app.
// - The feed pages lazily: 200 deals scroll in 10 requests, never more
//   than one per page, with only the visible cards built.
// - No rebuild storm: an idle Home rebuilds nothing; scrolling rebuilds
//   cards, not the screen.
// - The Saved tab with the maximum 500 saves: few requests, lazy rows.
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import 'phase4_harness.dart';

const _onboarded = ShopperPreferences(onboarded: true, cityId: karachiId);

/// [n] made-up nationwide deals, newest first, one hour apart, as the feed
/// RPC returns them (keyset paging on published_at, id).
final class _BigFeed extends ServerGateway {
  new(super.auth, this.n);

  final int n;
  late final List<Map<String, Object?>> _rows = () {
    final base = DateTime.now().toUtc();
    return [
      for (var i = 0; i < n; i++)
        {
          'id':
              '00000000-0000-4000-00ff-${(n - i).toString().padLeft(12, '0')}',
          'brand_id': brandBySlug('demo-threads')['id'],
          'brand_slug': 'demo-threads',
          'brand_name': 'Threads (Demo)',
          'brand_name_ur': 'تھریڈز (ڈیمو)',
          'brand_logo_path': null,
          'brand_is_verified': true,
          'category_id': brandBySlug('demo-threads')['category_id'],
          'category_slug': 'fashion',
          'kind': 'brand_sale',
          'scope': 'nationwide',
          'status': 'published',
          'title_en': 'Bulk deal $i',
          'title_ur': 'ڈیل $i',
          'offer_kind': 'percent_off',
          'percent': 10 + i % 60,
          'amount_off_pkr': null,
          'price_pkr': null,
          'original_price_pkr': null,
          'offer_text_en': null,
          'offer_text_ur': null,
          'promo_code': null,
          'url': null,
          'image_path': null,
          'starts_at': base
              .subtract(const Duration(days: 30))
              .toIso8601String(),
          'ends_at': base.add(const Duration(days: 20)).toIso8601String(),
          'verified_at': base.toIso8601String(),
          'published_at': base
              .subtract(Duration(hours: i + 1))
              .toIso8601String(),
          'card_banks': <String>[],
          'is_featured': false,
          'distance_m': null,
        },
    ];
  }();

  int feedCalls = 0;
  final cursors = <String?>[];

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function != 'feed') return await super.rpc(function, params);
    calls.add('rpc:feed');
    feedCalls++;
    final after = params['after_published_at'] as String?;
    cursors.add(after);
    final size = ((params['page_size'] as int?) ?? 20).clamp(1, 50);
    final start = after == null
        ? 0
        : _rows.indexWhere(
                (r) =>
                    (r['published_at']! as String).compareTo(after) < 0 ||
                    ((r['published_at']! as String) == after &&
                        (r['id']! as String).compareTo(
                              params['after_id']! as String,
                            ) <
                            0),
              ) -
              0;
    if (start < 0) return const [];
    return _rows.skip(start).take(size).toList();
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (query.table == 'deal_cards' && query.inList.containsKey('id')) {
      final ids = query.inList['id']!;
      calls.add('select:deal_cards');
      return [
        for (final r in _rows)
          if (ids.contains(r['id'])) Map.of(r),
      ];
    }
    return await super.select(query);
  }

  List<String> get ids => [for (final r in _rows) r['id']! as String];
}

void main() {
  testWidgets('the feed: 200 deals in 10 page requests, no duplicates, and '
      'only the visible cards built', (tester) async {
    final jj = Journey(
      saved: _onboarded,
      backend: (auth) => _BigFeed(auth, 200),
    );
    final big = jj.server as _BigFeed;
    await jj.pump(tester, size: const Size(360, 800));
    expect(find.byType(HomeScreen), findsOneWidget);
    var maxBuilt = 0;
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 400; i++) {
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final built = find.byType(DealCard).evaluate().length;
      if (built > maxBuilt) maxBuilt = built;
      if (find
          .text("You've seen all the new deals. Check back soon.")
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
    expect(
      find.text("You've seen all the new deals. Check back soon."),
      findsOneWidget,
    );
    // 10 full pages, plus at most one empty page that confirms the end.
    expect(big.feedCalls, inInclusiveRange(10, 11), reason: '${big.cursors}');
    expect(
      big.cursors.toSet().length,
      big.cursors.length,
      reason: 'no page asked twice',
    );
    // Lazy: the carousels (at most 20 each) plus a screenful of the feed.
    expect(maxBuilt, lessThan(90), reason: 'built at once: $maxBuilt');
  });

  testWidgets('no rebuild storm: idle Home rebuilds nothing; a scroll does '
      'not rebuild the screen', (tester) async {
    final j = Journey(saved: _onboarded);
    await j.pump(tester, size: const Size(360, 800));
    final rebuilt = <String>[];
    widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuilt.add(element.widget.runtimeType.toString());
    };
    addTearDown(() => widgets.debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(rebuilt, isEmpty, reason: 'idle for 10 s: $rebuilt');
    final calls = j.server.calls.length;
    rebuilt.clear();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(rebuilt.where((w) => w == 'HomeScreen'), isEmpty);
    expect(
      j.server.calls.length - calls,
      lessThanOrEqualTo(1),
      reason: 'a scroll is not a reload: ${j.server.calls.skip(calls)}',
    );
  });

  testWidgets('Saved with the maximum 500 saves: at most 5 reads, lazy rows', (
    tester,
  ) async {
    final jj = Journey(
      saved: _onboarded,
      backend: (auth) => _BigFeed(auth, 500),
    );
    final big = jj.server as _BigFeed;
    jj.store.values[savedDealsKey] = '["${big.ids.join('","')}"]';
    await jj.pump(tester, size: const Size(360, 800));
    big.calls.clear();
    await tapTab(tester, 'Saved');
    expect(jj.container.read(savedDealsProvider), hasLength(500));
    final reads = [
      for (final c in big.calls)
        if (c == 'select:deal_cards') c,
    ];
    expect(reads.length, lessThanOrEqualTo(5), reason: '$reads');
    expect(find.text('Active (500)'), findsOneWidget);
    expect(find.byType(DealCard).evaluate().length, lessThan(20));
  });
}
