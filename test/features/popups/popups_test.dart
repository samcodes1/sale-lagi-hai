import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/popups/application/popup_providers.dart';
import 'package:sale_lagi_hai/features/popups/data/backend_popup_repository.dart';
import 'package:sale_lagi_hai/features/popups/domain/popup_banner.dart';
import 'package:sale_lagi_hai/features/popups/presentation/popup_gate.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

final _now = DateTime(2026, 11, 7, 12);

Map<String, Object?> _row({
  String id = 'p1',
  String title = 'Mega sale weekend',
  String frequency = 'once',
  String? cityId,
  String? link,
  String? dealId,
  String? brandSlug,
  String? action,
  String? sponsor,
}) => {
  'id': id,
  'sponsor_name': sponsor,
  'title_en': title,
  'title_ur': null,
  'body_en': 'Up to 70% off across Pakistan.',
  'body_ur': null,
  'image_path': null,
  'action_label_en': action,
  'action_label_ur': null,
  'link_url': link,
  'deal_id': dealId,
  'brand': brandSlug == null ? null : {'slug': brandSlug},
  'city_id': cityId,
  'frequency': frequency,
};

final class _Gateway implements BackendGateway {
  new(this.rows);

  final List<Map<String, Object?>> rows;
  TableQuery? query;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    this.query = query;
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Links implements LinkService {
  final opened = <String>[];

  @override
  Future<bool> openWeb(String url) async {
    opened.add(url);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'Test',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

void main() {
  group('BackendPopupRepository', () {
    test('reads running pop-ups by priority, with their targets', () async {
      final backend = _Gateway([
        _row(link: 'https://shop.example.pk', action: 'Shop now'),
        _row(id: 'p2', dealId: 'd1', action: 'See deal', frequency: 'daily'),
        _row(id: 'p3', brandSlug: 'khaadi', action: 'Follow'),
        _row(id: 'p4', frequency: 'every_launch', sponsor: 'Acme'),
      ]);
      final popups = await BackendPopupRepository(backend).live();
      expect(backend.query!.table, 'popup_banners');
      expect(backend.query!.orderBy, 'priority');
      expect((popups[0].target! as PopupLink).url, 'https://shop.example.pk');
      expect((popups[1].target! as PopupDeal).dealId, 'd1');
      expect(popups[1].frequency, PopupFrequency.daily);
      expect((popups[2].target! as PopupBrand).slug, 'khaadi');
      expect(popups[3].target, isNull);
      expect(popups[3].frequency, PopupFrequency.everyLaunch);
      expect(popups[3].sponsorName, 'Acme');
    });

    test('a malformed row throws', () async {
      final bad = {..._row(), 'frequency': 'hourly'};
      expect(
        () => BackendPopupRepository(_Gateway([bad])).live(),
        throwsFormatException,
      );
    });
  });

  group('PopupBanner.isDue', () {
    PopupBanner popup(PopupFrequency f) =>
        PopupBanner(id: 'x', titleEn: 'X', frequency: f);

    test('never seen: always due', () {
      for (final f in PopupFrequency.values) {
        expect(popup(f).isDue(lastSeen: null, now: _now), isTrue);
      }
    });

    test('once: never again', () {
      expect(
        popup(PopupFrequency.once).isDue(
          lastSeen: _now.subtract(const Duration(days: 30)),
          now: _now,
        ),
        isFalse,
      );
    });

    test('daily: again on the next calendar day, not the same day', () {
      final daily = popup(PopupFrequency.daily);
      expect(daily.isDue(lastSeen: DateTime(2026, 11, 7, 8), now: _now), isFalse);
      expect(
        daily.isDue(lastSeen: DateTime(2026, 11, 6, 23), now: _now),
        isTrue,
      );
    });

    test('every launch: always', () {
      expect(
        popup(PopupFrequency.everyLaunch).isDue(lastSeen: _now, now: _now),
        isTrue,
      );
    });
  });

  group('PopupSeenStore', () {
    test('remembers when each was seen, and keeps only the latest 50', () async {
      final kv = InMemoryKeyValueStore();
      final store = PopupSeenStore(kv);
      for (var i = 0; i < 60; i++) {
        await store.markSeen('p$i', _now.add(Duration(minutes: i)));
      }
      final seen = await store.read();
      expect(seen, hasLength(50));
      expect(seen.containsKey('p59'), isTrue);
      expect(seen.containsKey('p0'), isFalse);
      expect(seen['p59'], _now.add(const Duration(minutes: 59)));
    });

    test('a corrupt entry reads as nothing seen', () async {
      final kv = InMemoryKeyValueStore();
      await kv.setString(PopupSeenStore.key, '{broken');
      expect(await PopupSeenStore(kv).read(), isEmpty);
    });
  });

  group('popupToShowProvider', () {
    Future<PopupBanner?> pick(
      List<Map<String, Object?>> rows, {
      String? city,
      Map<String, DateTime> seen = const {},
    }) async {
      final kv = InMemoryKeyValueStore();
      await kv.setString(
        PopupSeenStore.key,
        jsonEncode({
          for (final MapEntry(:key, :value) in seen.entries)
            key: value.toIso8601String(),
        }),
      );
      final container = ProviderContainer(
        overrides: [
          backendGatewayProvider.overrideWithValue(_Gateway(rows)),
          keyValueStoreProvider.overrideWithValue(kv),
          homeCityProvider.overrideWithValue(city),
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(container.dispose);
      return await container.read(popupToShowProvider.future);
    }

    test('the first due one for the city', () async {
      final popup = await pick(
        [
          _row(id: 'lahore-only', cityId: 'lahore'),
          _row(id: 'seen'),
          _row(id: 'due'),
        ],
        city: 'karachi',
        seen: {'seen': _now.subtract(const Duration(days: 1))},
      );
      expect(popup?.id, 'due');
    });

    test('none due: none', () async {
      final popup = await pick(
        [_row(id: 'seen')],
        seen: {'seen': _now.subtract(const Duration(days: 1))},
      );
      expect(popup, isNull);
    });
  });

  group('PopupGate', () {
    Widget host({
      required List<Map<String, Object?>> rows,
      required InMemoryKeyValueStore kv,
      _Links? links,
      Locale locale = AppLocales.english,
    }) => testApp(
      const PopupGate(child: Scaffold(body: Text('Home'))),
      locale: locale,
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        backendGatewayProvider.overrideWithValue(_Gateway(rows)),
        keyValueStoreProvider.overrideWithValue(kv),
        homeCityProvider.overrideWithValue(null),
        clockProvider.overrideWithValue(() => _now),
        if (links != null) linkServiceProvider.overrideWithValue(links),
      ],
    );

    testWidgets('shows the due pop-up over Home and records it as seen', (
      tester,
    ) async {
      final kv = InMemoryKeyValueStore();
      await tester.pumpWidget(host(rows: [_row()], kv: kv));
      await tester.pumpAndSettle();
      expect(find.byType(PopupBannerDialog), findsOneWidget);
      expect(find.text('Mega sale weekend'), findsOneWidget);
      expect((await PopupSeenStore(kv).read()).keys, ['p1']);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupBannerDialog), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('no pop-up running: nothing over Home', (tester) async {
      await tester.pumpWidget(host(rows: const [], kv: InMemoryKeyValueStore()));
      await tester.pumpAndSettle();
      expect(find.byType(PopupBannerDialog), findsNothing);
    });

    testWidgets('the button closes it and opens the link', (tester) async {
      final links = _Links();
      await tester.pumpWidget(
        host(
          rows: [
            _row(link: 'https://shop.example.pk', action: 'Shop now'),
          ],
          kv: InMemoryKeyValueStore(),
          links: links,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shop now'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupBannerDialog), findsNothing);
      expect(links.opened, ['https://shop.example.pk']);
    });

    testWidgets('a sponsored pop-up says who it is from', (tester) async {
      await tester.pumpWidget(
        host(rows: [_row(sponsor: 'Acme')], kv: InMemoryKeyValueStore()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sponsored by Acme'), findsOneWidget);
    });

    testWidgets('fits 200% Urdu text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        host(
          rows: [_row(link: 'https://shop.example.pk', action: 'Shop now')],
          kv: InMemoryKeyValueStore(),
          locale: AppLocales.urdu,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupBannerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
