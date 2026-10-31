import 'dart:math' as math;

import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// An in-memory backend with the demo data, for builds without Supabase
/// (dev, tests, web QA). It answers the same tables, view and RPCs as the
/// real backend (docs/backend/API.md), with the same rules: live deals
/// only in lists, local deals only in their (live) city, keyset paging,
/// pages of at most 50. Follows, saves and cards live in memory for one
/// demo user.
final class DemoGateway implements BackendGateway {
  new({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// The demo user's id (follows, saves, cards).
  static const userId = '00000000-0000-4000-9000-000000000001';

  final _tables = <String, List<Map<String, Object?>>>{
    'follows': [],
    'saves': [],
    'user_cards': [],
    'reports': [],
  };

  static const List<({int deal, String? city, int priority})> _placements = [
    (deal: 4, city: null, priority: 5),
    (deal: 1, city: karachiId, priority: 9),
  ];

  List<Map<String, Object?>> _dealCards() {
    final now = _clock().toUtc();
    final categories = {for (final c in demoCategories) c['id']: c};
    return [
      for (final d in demoDeals)
        () {
          final brand = brandBySlug(d.brand);
          final category = categories[brand['category_id']]!;
          final published = now.subtract(Duration(hours: d.publishedHoursAgo));
          return <String, Object?>{
            'id': d.id,
            'brand_id': brand['id'],
            'brand_slug': brand['slug'],
            'brand_name': brand['name'],
            'brand_name_ur': brand['name_ur'],
            'brand_logo_path': null,
            'brand_is_verified': true,
            'category_id': category['id'],
            'category_slug': category['slug'],
            'kind': d.kind,
            'scope': d.scope,
            'status': 'published',
            'title_en': d.titleEn,
            'title_ur': d.titleUr,
            'offer_kind': d.offerKind,
            'percent': d.percent,
            'amount_off_pkr': d.amountOff,
            'price_pkr': d.price,
            'original_price_pkr': d.originalPrice,
            'offer_text_en': d.offerTextEn,
            'offer_text_ur': d.offerTextUr,
            'promo_code': d.promoCode,
            'url': d.url,
            'image_path': null,
            'starts_at': published
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'ends_at': d.endsInHours == null
                ? null
                : now.add(Duration(hours: d.endsInHours!)).toIso8601String(),
            'verified_at': now
                .subtract(Duration(hours: d.verifiedHoursAgo))
                .toIso8601String(),
            'published_at': published.toIso8601String(),
            'card_banks': [
              if (d.cardBank case final bank?)
                demoBanks.firstWhere((b) => b['slug'] == bank)['short_name'],
            ],
            'is_featured': false,
            'distance_m': null,
          };
        }(),
    ];
  }

  DemoDeal _demo(String id) => demoDeals.firstWhere((d) => d.id == id);

  bool _shownInCity(Map<String, Object?> deal, String? cityId) {
    if (deal['scope'] != 'local') return true;
    if (cityId == null) return false;
    final city = demoCities.firstWhere(
      (c) => c['id'] == cityId,
      orElse: () => const {},
    );
    // All demo local deals are in Karachi.
    return city['is_live'] == true && cityId == karachiId;
  }

  bool _inCategories(Map<String, Object?> deal, List<Object?>? wanted) {
    if (wanted == null) return true;
    final id = deal['category_id'];
    final parent = demoCategories.firstWhere((c) => c['id'] == id)['parent_id'];
    return wanted.contains(id) || wanted.contains(parent);
  }

  static int _pageSize(Object? requested) =>
      ((requested as int?) ?? 20).clamp(1, 50);

  List<Map<String, Object?>> _page(
    Iterable<Map<String, Object?>> deals,
    Map<String, Object?> p,
  ) {
    final sorted = deals.toList()
      ..sort((a, b) {
        final byTime = (b['published_at']! as String).compareTo(
          a['published_at']! as String,
        );
        return byTime != 0
            ? byTime
            : (b['id']! as String).compareTo(a['id']! as String);
      });
    final afterAt = p['after_published_at'] as String?;
    final afterId =
        p['after_id'] as String? ?? 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    final after = afterAt == null
        ? sorted
        : sorted.where((d) {
            final at = DateTime.parse(d['published_at']! as String);
            final cursor = DateTime.parse(afterAt);
            return at.isBefore(cursor) ||
                (at.isAtSameMomentAs(cursor) &&
                    (d['id']! as String).compareTo(afterId) < 0);
          });
    return after.take(_pageSize(p['page_size'])).toList();
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    final live = _dealCards();
    final cityId = params['city_id'] as String?;
    switch (function) {
      case 'feed':
        final following = params['following_only'] == true;
        return _page(
          live.where(
            (d) =>
                _shownInCity(d, cityId) &&
                _inCategories(d, params['category_ids'] as List<Object?>?) &&
                (!following || _follows(d)),
          ),
          params,
        );
      case 'featured_deals':
        if (params['slot'] != 'home_featured') return const [];
        final placements =
            _placements
                .where((p) => p.city == null || p.city == cityId)
                .toList()
              ..sort((a, b) => b.priority.compareTo(a.priority));
        return [
          for (final p in placements)
            for (final d in live)
              if (d['id'] == demoDeals.firstWhere((x) => x.n == p.deal).id &&
                  _shownInCity(d, cityId))
                {...d, 'is_featured': true},
        ];
      case 'trending_deals':
        final saves = <Object?, int>{};
        for (final s in _tables['saves']!) {
          saves[s['deal_id']] = (saves[s['deal_id']] ?? 0) + 1;
        }
        return (live.where((d) => _shownInCity(d, cityId)).toList()..sort(
              (a, b) => (saves[b['id']] ?? 0).compareTo(saves[a['id']] ?? 0),
            ))
            .take(_pageSize(params['page_size']))
            .toList();
      case 'nearby_deals':
        final lat = (params['lat']! as num).toDouble();
        final lng = (params['lng']! as num).toDouble();
        final radius = ((params['radius_m'] as int?) ?? 3000).clamp(100, 20000);
        final results = <Map<String, Object?>>[];
        for (final d in live) {
          if (d['scope'] == 'online') continue;
          final demo = _demo(d['id']! as String);
          final distances = [
            for (final (brand, area, oLat, oLng) in demoOutlets)
              if (brand == d['brand_slug'] &&
                  (demo.areas.isEmpty || demo.areas.contains(area)))
                _metres(lat, lng, oLat, oLng),
          ].where((m) => m <= radius);
          if (distances.isEmpty) continue;
          results.add({...d, 'distance_m': distances.reduce(math.min).round()});
        }
        results.sort(
          (a, b) =>
              (a['distance_m']! as int).compareTo(b['distance_m']! as int),
        );
        return results.take(_pageSize(params['page_size'])).toList();
      case 'deals_for_my_cards':
        final myBanks = {
          for (final uc in _tables['user_cards']!)
            demoCardProducts.firstWhere(
              (p) => p['id'] == uc['card_product_id'],
            )['bank_id'],
        };
        final bankNames = {
          for (final b in demoBanks)
            if (myBanks.contains(b['id'])) b['short_name'],
        };
        return _page(
          live.where(
            (d) =>
                d['kind'] == 'card_offer' &&
                _shownInCity(d, cityId) &&
                (d['card_banks']! as List).any(bankNames.contains),
          ),
          params,
        );
      case 'deals_for_cards':
        final ids = [
          ...((params['card_product_ids'] as List<Object?>?) ?? const []),
        ].take(20).toSet();
        final cards = [
          for (final p in demoCardProducts)
            if (ids.contains(p['id']) && p['is_active'] == true) p,
        ];
        return _page(
          live.where((d) {
            if (d['kind'] != 'card_offer' || !_shownInCity(d, cityId)) {
              return false;
            }
            final bank = _demo(d['id']! as String).cardBank;
            return cards.any(
              (c) => demoBanks.any(
                (b) => b['id'] == c['bank_id'] && b['slug'] == bank,
              ),
            );
          }),
          params,
        );
      case 'search_deals':
        final query = (params['query'] as String? ?? '').trim().toLowerCase();
        if (query.length == 1 || query.length > 100) return const [];
        bool matches(String text) {
          final words = text.toLowerCase().split(RegExp(r'\W+'));
          return text.toLowerCase().contains(query) ||
              query
                  .split(RegExp(r'\s+'))
                  .every((q) => words.any((w) => _close(q, w)));
        }
        final found = live
            .where(
              (d) =>
                  _shownInCity(d, cityId) &&
                  _inCategories(d, params['category_ids'] as List<Object?>?) &&
                  _passesSearchFilters(d, params) &&
                  (query.isEmpty ||
                      matches(d['title_en']! as String) ||
                      matches(d['brand_name']! as String) ||
                      (d['title_ur']! as String).contains(query)),
            )
            .toList();
        // Words: best first (here, the demo's own order); none: newest.
        final ordered = query.isEmpty
            ? _page(found, const {'page_size': 50})
            : found;
        final afterId = params['after_id'] as String?;
        final start = afterId == null
            ? 0
            : ordered.indexWhere((d) => d['id'] == afterId) + 1;
        // A deal no longer in the results ends the list.
        if (afterId != null && start == 0) return const [];
        return ordered
            .skip(start)
            .take(_pageSize(params['page_size']))
            .toList();
      case 'ending_soon_deals':
        final hours = ((params['within_hours'] as int?) ?? 72).clamp(1, 168);
        final now = _clock().toUtc();
        final limit = now.add(Duration(hours: hours));
        final ending =
            [
              for (final d in live)
                if (d['ends_at'] case final String ends
                    when DateTime.parse(ends).isAfter(now) &&
                        !DateTime.parse(ends).isAfter(limit) &&
                        _shownInCity(d, cityId))
                  d,
            ]..sort(
              (a, b) =>
                  (a['ends_at']! as String).compareTo(b['ends_at']! as String),
            );
        return ending.take(_pageSize(params['page_size'])).toList();
      case 'sync_guest_preferences':
        // Follows active brands the demo user doesn't follow yet.
        for (final id in (params['brand_ids'] as List<Object?>?) ?? const []) {
          final active = demoBrands.any(
            (b) => b['id'] == id && b['is_active'] == true,
          );
          final already = _tables['follows']!.any((f) => f['brand_id'] == id);
          if (active && !already) {
            _tables['follows']!.add({'user_id': userId, 'brand_id': id});
          }
        }
        for (final id
            in (params['category_ids'] as List<Object?>?) ?? const []) {
          final known = demoCategories.any((c) => c['id'] == id);
          final already = _tables['follows']!.any(
            (f) => f['category_id'] == id,
          );
          if (known && !already) {
            _tables['follows']!.add({'user_id': userId, 'category_id': id});
          }
        }
        return const [];
      case 'sync_guest_items':
        // Visible deals and active card products, once each.
        for (final id in (params['deal_ids'] as List<Object?>?) ?? const []) {
          final known = demoDeals.any((d) => d.id == id);
          final already = _tables['saves']!.any((r) => r['deal_id'] == id);
          if (known && !already) {
            _tables['saves']!.add({'user_id': userId, 'deal_id': id});
          }
        }
        for (final id
            in (params['card_product_ids'] as List<Object?>?) ?? const []) {
          final active = demoCardProducts.any(
            (c) => c['id'] == id && c['is_active'] != false,
          );
          final already = _tables['user_cards']!.any(
            (r) => r['card_product_id'] == id,
          );
          if (active && !already) {
            _tables['user_cards']!.add({
              'user_id': userId,
              'card_product_id': id,
            });
          }
        }
        return const [];
      case 'my_alert_prefs':
        return [Map.of(_alertPrefs)];
      case 'update_alert_prefs':
        if (params['quiet_start'] != null &&
            params['quiet_start'] ==
                (params['quiet_end'] ?? _alertPrefs['quiet_end'])) {
          throw const PostgrestException(message: 'check', code: '23514');
        }
        for (final MapEntry(:key, :value) in params.entries) {
          if (value != null) _alertPrefs[key] = value;
        }
        return [Map.of(_alertPrefs)];
      case 'mark_alerts_read':
        final ids = params['ids'] as List<Object?>?;
        var changed = 0;
        for (final n in _notifications) {
          if (n['read_at'] == null && (ids == null || ids.contains(n['id']))) {
            n['read_at'] = _clock().toUtc().toIso8601String();
            changed++;
          }
        }
        return [
          {'value': changed},
        ];
      case 'unread_alert_count':
        final since = params['since'] as String?;
        return [
          {
            'value': [
              for (final n in _notifications)
                if (n['read_at'] == null &&
                    (since == null ||
                        (n['created_at']! as String).compareTo(since) > 0))
                  n,
            ].length,
          },
        ];
      case 'brand_suggestions':
        final words = (params['query'] as String? ?? '').trim().toLowerCase();
        if (words.isEmpty || words.length > 60) return const [];
        final starts = [
          for (final b in demoBrands)
            if (b['is_active'] == true &&
                ((b['name']! as String).toLowerCase().startsWith(words) ||
                    ((b['name_ur'] as String?) ?? '').startsWith(words)))
              b,
        ];
        final close = [
          for (final b in demoBrands)
            if (b['is_active'] == true &&
                !starts.contains(b) &&
                (b['name']! as String)
                    .toLowerCase()
                    .split(RegExp(r'\W+'))
                    .any((w) => _close(words, w)))
              b,
        ];
        return [
          ...starts,
          ...close,
        ].take(((params['page_size'] as int?) ?? 6).clamp(1, 10)).toList();
      case 'brand_deals':
        return _page(
          live.where(
            (d) =>
                d['brand_slug'] == params['brand_slug'] &&
                _shownInCity(d, cityId),
          ),
          params,
        );
    }
    throw UnsupportedError('demo backend has no RPC $function');
  }

  /// search_deals' area, bank, discount and ending-soon filters.
  bool _passesSearchFilters(Map<String, Object?> deal, Map<String, Object?> p) {
    if (p['area_id'] case final String areaId when deal['scope'] == 'local') {
      final slug = demoAreas.firstWhere(
        (a) => a['id'] == areaId,
        orElse: () => const {},
      )['slug'];
      final areas = _demo(deal['id']! as String).areas;
      if (slug == null || (areas.isNotEmpty && !areas.contains(slug))) {
        return false;
      }
    }
    if (p['bank_ids'] case final List<Object?> bankIds
        when bankIds.isNotEmpty) {
      final names = {
        for (final b in demoBanks)
          if (bankIds.contains(b['id'])) b['short_name'],
      };
      if (!(deal['card_banks']! as List).any(names.contains)) return false;
    }
    if (p['min_percent'] case final int min) {
      // "Up to 50% off" is not at least 50% off.
      final percent = deal['percent'] as int?;
      if (!const {
            'percent_off',
            'flat_percent_off',
          }.contains(deal['offer_kind']) ||
          percent == null ||
          percent < min.clamp(1, 99)) {
        return false;
      }
    }
    if (p['ending_within_hours'] case final int hours) {
      final ends = deal['ends_at'] as String?;
      final limit = _clock().toUtc().add(Duration(hours: hours.clamp(1, 336)));
      if (ends == null || DateTime.parse(ends).isAfter(limit)) return false;
    }
    return true;
  }

  /// The alert planner's rules: the brand; the category or its parent; a
  /// bank whose cards the deal needs; or, for local deals, a city they
  /// target (all demo local deals are in Karachi).
  bool _follows(Map<String, Object?> deal) {
    final parent = demoCategories.firstWhere(
      (c) => c['id'] == deal['category_id'],
    )['parent_id'];
    final bankIds = {
      for (final b in demoBanks)
        if ((deal['card_banks']! as List).contains(b['short_name'])) b['id'],
    };
    return _tables['follows']!.any(
      (f) =>
          f['user_id'] == userId &&
          (f['brand_id'] == deal['brand_id'] ||
              (f['category_id'] != null &&
                  (f['category_id'] == deal['category_id'] ||
                      f['category_id'] == parent)) ||
              (f['bank_id'] != null && bankIds.contains(f['bank_id'])) ||
              (deal['scope'] == 'local' && f['city_id'] == karachiId)),
    );
  }

  /// Typo tolerance like pg_trgm's: one edit per four letters.
  static bool _close(String a, String b) {
    if (a == b || (a.length >= 3 && b.startsWith(a))) return true;
    final limit = (a.length / 4).floor();
    if (limit == 0 || (a.length - b.length).abs() > limit) return false;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List<int>.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce(math.min);
      }
      previous = current;
    }
    return previous[b.length] <= limit;
  }

  static double _metres(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// The deal page's long text, as the deals table has it.
  static final List<Map<String, Object?>> _dealTexts = [
    for (final d in demoDeals)
      <String, Object?>{
        'id': d.id,
        'description_en':
            'A made-up deal for trying the app: ${d.titleEn}. Real deals '
            "show the brand's own description here.",
        'description_ur':
            'ایپ آزمانے کے لیے ایک فرضی ڈیل: ${d.titleUr}۔ اصل ڈیلز میں یہاں '
            'برانڈ کی اپنی تفصیل ہوتی ہے۔',
        'terms_en': 'Demo terms: while stocks last. One per customer.',
        'terms_ur': 'ڈیمو شرائط: اسٹاک رہنے تک۔ فی گاہک ایک۔',
        'source_url': d.url,
      },
  ];

  static final List<Map<String, Object?>> _outlets = [
    for (final (i, (brand, area, lat, lng)) in demoOutlets.indexed)
      () {
        final b = brandBySlug(brand);
        final a = demoAreas.firstWhere((x) => x['slug'] == area);
        return <String, Object?>{
          'id':
              '00000000-0000-4000-0007-${(i + 1).toString().padLeft(12, '0')}',
          'brand_id': b['id'],
          'city_id': karachiId,
          'area_id': a['id'],
          'name': '${b['name']} · ${a['name_en']}',
          'address': '${a['name_en']}, Karachi',
          'phone': null,
          'latitude': lat,
          'longitude': lng,
          'is_active': true,
        };
      }(),
  ];

  /// The demo user's alert preferences (the table's defaults).
  final Map<String, Object?> _alertPrefs = {
    'push_enabled': false,
    'frequency': 'normal',
    'quiet_start': '22:00:00',
    'quiet_end': '08:00:00',
    'time_zone': 'Asia/Karachi',
    'followed_brands': true,
    'followed_categories': true,
    'my_cards': true,
    'my_city': true,
    'saved_price_drops': true,
    'saved_expiring': true,
  };

  /// The demo inbox: three alerts about demo deals, newest first.
  late final List<Map<String, Object?>> _notifications = [
    for (final (i, (n, kind, en, minutesAgo, read)) in const [
      (1, 'deal_alert', 'Karahi House (Demo): Family karahi for 4', 20, false),
      (
        9,
        'deal_alert',
        'Burger Point (Demo): Meezan debit card 15% off',
        300,
        false,
      ),
      (
        4,
        'expiring_saved',
        'Threads (Demo): a saved deal ends soon',
        1800,
        true,
      ),
    ].indexed)
      {
        'id': '00000000-0000-4000-0008-${(i + 1).toString().padLeft(12, '0')}',
        'user_id': userId,
        'kind': kind,
        'title': en,
        'body': demoDeals.firstWhere((d) => d.n == n).titleEn,
        'deal_id': demoDeals.firstWhere((d) => d.n == n).id,
        'created_at': _clock()
            .toUtc()
            .subtract(Duration(minutes: minutesAgo))
            .toIso8601String(),
        'read_at': read ? _clock().toUtc().toIso8601String() : null,
      },
  ];

  static final List<Map<String, Object?>> _dealTargets = [
    for (final d in demoDeals)
      if (d.scope == 'local')
        if (d.areas.isEmpty)
          <String, Object?>{
            'deal_id': d.id,
            'city_id': karachiId,
            'area_id': null,
          }
        else
          for (final area in d.areas)
            <String, Object?>{
              'deal_id': d.id,
              'city_id': karachiId,
              'area_id': demoAreas.firstWhere((x) => x['slug'] == area)['id'],
            },
  ];

  List<Map<String, Object?>> _rows(String table) => switch (table) {
    'cities' => demoCities,
    'areas' => demoAreas,
    'categories' => demoCategories,
    'banks' => demoBanks,
    'card_products' => demoCardProducts,
    'brands' => demoBrands,
    'deal_cards' => _dealCards(),
    'deals' => _dealTexts,
    'outlets' => _outlets,
    'deal_targets' => _dealTargets,
    'notifications' => _notifications,
    'sponsor_banners' => demoSponsorBanners,
    final other =>
      _tables[other] ??
          (throw UnsupportedError('demo backend has no table $other')),
  };

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    var rows = _rows(query.table).where((row) {
      for (final MapEntry(:key, :value) in query.equals.entries) {
        if (row[key] != value) return false;
      }
      for (final MapEntry(:key, :value) in query.inList.entries) {
        if (!value.contains(row[key])) return false;
      }
      return true;
    }).toList();
    if (query.orderBy case final column?) {
      rows.sort((a, b) {
        final x = a[column];
        final y = b[column];
        final order = x is Comparable && y != null ? x.compareTo(y) : 0;
        return query.ascending ? order : -order;
      });
    }
    rows = rows.skip(query.offset).toList();
    if (query.limit case final limit?) rows = rows.take(limit).toList();
    return [for (final row in rows) Map.of(row)];
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    final rows = _tables[table];
    if (rows == null) {
      throw UnsupportedError('demo backend cannot write $table');
    }
    // public.reports: unique (deal_id, reporter_id), as on the server.
    if (table == 'reports' && rows.any((r) => r['deal_id'] == row['deal_id'])) {
      throw const PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    }
    rows.add({'user_id': userId, ...row});
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {
    if (match.isEmpty) {
      throw ArgumentError.value(match, 'match', 'must not be empty');
    }
    _tables[table]?.removeWhere(
      (row) => match.entries.every((e) => row[e.key] == e.value),
    );
  }
}
