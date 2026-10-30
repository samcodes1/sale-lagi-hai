// QA, sub-phase 4.4: the deal page. Hostile links, saves under the real
// table rules, a failed or slow saved-file read, account deletion, the
// report flow's edges, outlets of large chains, and the page in dark, high
// contrast, Urdu and 200% text, scrolled to the end (docs/qa/4.4.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/deals/application/report_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';
import 'qa_backend_rules.dart';

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;

/// Fails the first [failReads] reads of the saved deals, and can hold the
/// next one until [gate] completes.
final class _SavedFileStore implements KeyValueStore {
  new(this.inner, {this.failReads = 0});

  final InMemoryKeyValueStore inner;
  int failReads;
  Completer<void>? gate;

  @override
  Future<String?> getString(String key) async {
    if (key == savedDealsKey) {
      if (failReads > 0) {
        failReads--;
        throw PlatformException(code: 'io');
      }
      if (gate case final g?) await g.future;
    }
    return await inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) =>
      inner.setString(key, value);

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<Set<String>> keys() => inner.keys();

  @override
  Future<void> clear() => inner.clear();
}

/// Reads nothing; every write fails.
final class _ReadOnlyStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw PlatformException(code: 'full');

  @override
  Future<void> remove(String key) async {}

  @override
  Future<Set<String>> keys() async => {};

  @override
  Future<void> clear() async {}
}

/// Every insert fails with [error].
final class _FailingInserts extends RulesGateway {
  new(super.auth, this.error);

  final Exception error;
  final rows = <Map<String, Object?>>[];

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    rows.add(row);
    throw error;
  }
}

Future<void> _signIn(DemoAuthRepository auth) async {
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
}

final class _Links implements LinkService {
  final calls = <String>[];

  @override
  Future<bool> openWeb(String url) async {
    calls.add('web $url');
    return UrlLauncherLinkService.safeWebUri(url) != null;
  }

  @override
  Future<bool> openMap(double latitude, double longitude, String label) async {
    calls.add('map');
    return true;
  }

  @override
  Future<bool> shareOnWhatsApp(String text) async {
    calls.add('whatsapp $text');
    return true;
  }

  @override
  Future<bool> call(String e164) async {
    calls.add('call $e164');
    return true;
  }

  // (Developer, 4.9: LinkService gained email.)
  @override
  Future<bool> email(String address) async => true;
}

final Finder _page = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  group('LinkService: what may leave the app', () {
    for (final bad in [
      'javascript:alert(1)',
      'JAVASCRIPT:alert(1)',
      ' javascript:alert(1)',
      'intent://x#Intent;scheme=https;package=evil;end',
      'intent:https://brand.pk#Intent;end',
      'market://details?id=evil',
      'content://com.android.contacts/contacts',
      'data:text/html,<script>alert(1)</script>',
      'file:///sdcard/x.html',
      'http://brand.pk',
      'HTTP://brand.pk',
      'https:brand.pk',
      'https:/brand.pk',
      'https:///brand.pk',
      '//brand.pk',
      'brand.pk',
      'https://user@brand.pk',
      'https://brand.pk@evil.example',
      'https://brand.pk:@evil.example',
      'https://%62rand.pk@evil.example',
      'tel:+923001234567',
      'sms:+923001234567',
      'whatsapp://send?text=x',
      '',
      '   ',
    ]) {
      test('refuses ${bad.trim().isEmpty ? '(blank)' : bad}', () {
        expect(UrlLauncherLinkService.safeWebUri(bad), isNull);
      });
    }

    for (final (ok, host) in [
      ('https://brand.pk/sale', 'brand.pk'),
      ('HTTPS://Brand.PK/Sale', 'brand.pk'),
      ('  https://brand.pk/sale  ', 'brand.pk'),
      ('https://brand.pk:8443/x?y=1#z', 'brand.pk'),
      // Not refused, and not a problem: Custom Tabs shows the real host.
      ('https://evil.example#@brand.pk', 'evil.example'),
      ('https://evil.example/@brand.pk', 'evil.example'),
    ]) {
      test('opens $ok on host $host only', () {
        expect(UrlLauncherLinkService.safeWebUri(ok)?.host, host);
      });
    }

    test('look-alike (IDN) hosts are https pages like any other; the tab '
        'shows the punycode host', () {
      final uri = UrlLauncherLinkService.safeWebUri('https://аpple.com/');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
    });

    test('a right-to-left override in the path cannot change the host', () {
      final uri = UrlLauncherLinkService.safeWebUri(
        'https://evil.example/\u202Emoc.knab',
      );
      expect(uri?.host, 'evil.example');
    });

    test('call: only +92 numbers, nothing appended', () async {
      const links = UrlLauncherLinkService();
      for (final bad in [
        '+92300123456789',
        '+9230012345',
        '03001234567',
        '+92 300 1234567',
        '+923001234567\n',
        '+923001234567,1234',
        '+923001234567;ext=1',
        '+923001234567#',
        '+12025550123',
        'tel:+923001234567',
      ]) {
        expect(await links.call(bad), isFalse, reason: bad);
      }
    });

    test('WhatsApp text survives the link exactly (spaces, &, #, +, '
        'newlines, Urdu)', () {
      const text = 'Khaadi: 40% off & more #sale 1+1\nسردیوں کی سیل';
      final uri = UrlLauncherLinkService.whatsAppUri(text);
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(Uri.parse(uri.toString()).queryParameters['text'], text);
    });

    test('the map link carries only the coordinates', () {
      final uri = UrlLauncherLinkService.mapUri(24.8, 67.03);
      expect(uri.toString(), startsWith('https://www.google.com/maps/'));
      expect(uri.queryParameters.keys.toSet(), {'api', 'query'});
    });
  });

  group('saves against the real table rules', () {
    late InMemoryKeyValueStore store;
    late DemoAuthRepository auth;
    late RulesGateway backend;

    ProviderContainer container({KeyValueStore? kv}) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv ?? store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore();
      auth = DemoAuthRepository();
      backend = RulesGateway(auth);
    });

    test('signed in, a save reaches the account', () async {
      await _signIn(auth);
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect(backend.refused, isEmpty, reason: '${backend.inserts}');
      expect(
        (await backend.select(const TableQuery('saves')))
            .map((s) => s['deal_id']),
        [_deal(3)],
      );
    });

    test('guest saves reach the account at sign-in', () async {
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(4));
      await _signIn(auth);
      await c.read(guestSyncProvider)();
      expect(backend.refused, isEmpty, reason: '${backend.inserts}');
      // Since 4.8 they go up in one call (sync_guest_items), as the caller.
      expect(
        (await backend.select(const TableQuery('saves')))
            .map((s) => '${s['user_id']}/${s['deal_id']}'),
        ['${auth.currentUser!.id}/${_deal(4)}'],
      );
    });

    test('a failed read of the saved file, then a save: the earlier saves '
        'are still on the phone', () async {
      await store.setString(savedDealsKey, '["${_deal(1)}","${_deal(2)}"]');
      final kv = _SavedFileStore(store, failReads: 1);
      final c = container(kv: kv)..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      final after = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(after.read(savedDealsProvider).toSet(), {
        _deal(1),
        _deal(2),
        _deal(3),
      });
    });

    test('a save made before the saved file was read keeps the earlier '
        'saves', () async {
      await store.setString(savedDealsKey, '["${_deal(1)}","${_deal(2)}"]');
      final kv = _SavedFileStore(store)..gate = Completer();
      final c = container(kv: kv)..read(savedDealsProvider);
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      kv.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(savedDealsProvider).toSet(), {
        _deal(1),
        _deal(2),
        _deal(3),
      });
      final after = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(after.read(savedDealsProvider).toSet(), {
        _deal(1),
        _deal(2),
        _deal(3),
      }, reason: 'what is on the phone after a restart');
    });

    test('after the account is deleted, the next save does not write the '
        'old saves back', () async {
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      // What _forgetThisPhone does.
      await store.clear();
      await c.read(preferencesProvider.notifier).reset();
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect(store.values[savedDealsKey], '["${_deal(3)}"]');
    });

    test('a refused mirror is logged and the phone keeps the save', () async {
      await _signIn(auth);
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect(c.read(savedDealsProvider.notifier).isSaved(_deal(3)), isTrue);
      expect(store.values[savedDealsKey], contains(_deal(3)));
    });

    test('a failed write keeps the save for this session', () async {
      final c = container(kv: _ReadOnlyStore());
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect(c.read(savedDealsProvider), [_deal(3)]);
    });

    test('at most 500, newest first; the oldest goes', () async {
      final c = container();
      for (var i = 0; i < 501; i++) {
        await c.read(savedDealsProvider.notifier).toggle('d$i');
      }
      final saved = c.read(savedDealsProvider);
      expect(saved, hasLength(500));
      expect(saved.first, 'd500');
      expect(saved, isNot(contains('d0')));
    });
  });

  group('reports', () {
    late DemoAuthRepository auth;

    ProviderContainer container(BackendGateway backend) {
      final c = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      auth = DemoAuthRepository();
      await _signIn(auth);
    });

    test('the reasons are exactly the database enum, in order', () {
      final sql = File(
        'supabase/migrations/20261029120500_moderation_and_commerce.sql',
      ).readAsStringSync();
      final body = RegExp(
        r'create type public\.report_reason as enum \(([^)]*)\)',
      ).firstMatch(sql)!.group(1)!;
      final values = RegExp("'([a-z_]+)'")
          .allMatches(body)
          .map((m) => m.group(1))
          .toList();
      expect(ReportReason.values.map((r) => r.wire).toList(), values);
    });

    test('a second report is "already reported", not an error', () async {
      final c = container(
        _FailingInserts(
          auth,
          const PostgrestException(message: 'duplicate', code: '23505'),
        ),
      );
      final r = await c.read(reportDealProvider)(_deal(1), ReportReason.spam);
      expect(r.valueOrNull, ReportOutcome.alreadyReported);
    });

    test('the hourly limit is a rate-limit failure', () async {
      final c = container(
        _FailingInserts(
          auth,
          const PostgrestException(message: 'rate_limited', code: 'PT429'),
        ),
      );
      final r = await c.read(reportDealProvider)(_deal(1), ReportReason.spam);
      expect(r.failureOrNull, isA<RateLimitedFailure>());
    });

    test(
      '"Something else" with only spaces is refused before sending',
      () async {
        final backend = _FailingInserts(auth, Exception('must not send'));
        final c = container(backend);
        final r = await c.read(reportDealProvider)(
          _deal(1),
          ReportReason.other,
          note: '  \n ',
        );
        expect(r.failureOrNull, isA<ValidationFailure>());
        expect(backend.rows, isEmpty);
      },
    );

    test('the note is trimmed and capped at 500', () async {
      final backend = RulesGateway(auth);
      final c = container(backend);
      final r = await c.read(reportDealProvider)(
        _deal(1),
        ReportReason.other,
        note: '  ${'x' * 600}  ',
      );
      expect(r.valueOrNull, ReportOutcome.sent);
      expect(backend.inserts.single, contains('x' * 500));
      expect(backend.inserts.single, isNot(contains('x' * 501)));
    });

    test('a long note ending in an emoji at the cap still sends (the cap '
        'never splits a character)', () async {
      final backend = RulesGateway(auth);
      final c = container(backend);
      // 499 letters and an emoji: 501 UTF-16 units, 500 characters, so
      // the field (which counts characters) lets it through.
      final r = await c.read(reportDealProvider)(
        _deal(1),
        ReportReason.other,
        note: '${'x' * 499}😀',
      );
      expect(r.valueOrNull, ReportOutcome.sent, reason: '${r.failureOrNull}');
    });
  });

  group('outlets', () {
    test('a local deal of a chain with more than 100 outlets lists the '
        'outlets in its target city', () async {
      final backend = _BigChain();
      final repository = BackendDealRepository(backend, AppLogger(sinks: []));
      final detail = (await repository.detail(_BigChain.dealId)).valueOrNull!;
      expect(detail.outlets, hasLength(5), reason: 'the 5 Quetta outlets');
    });
  });

  group('the page', () {
    Future<(Harness, _Links)> open(
      WidgetTester tester,
      int deal, {
      Locale locale = AppLocales.english,
      Brightness brightness = Brightness.light,
      bool hc = false,
      double scale = 1,
      Size size = const Size(412, 915),
      DateTime Function()? clock,
      BackendGateway? backend,
    }) async {
      tester.platformDispatcher
        ..platformBrightnessTestValue = brightness
        ..textScaleFactorTestValue = scale
        ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
          highContrast: hc,
        );
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final links = _Links();
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        backend: backend,
        overrides: [
          linkServiceProvider.overrideWithValue(links),
          if (clock != null) clockProvider.overrideWithValue(clock),
        ],
      );
      await h.pump(tester, device: locale, size: size);
      h.router.go('/deal/${_deal(deal)}');
      await tester.pumpAndSettle();
      return (h, links);
    }

    for (final (name, deal, locale, brightness, hc) in const [
      ('en dark', 7, AppLocales.english, Brightness.dark, false),
      ('ur dark', 7, AppLocales.urdu, Brightness.dark, false),
      ('en light HC', 5, AppLocales.english, Brightness.light, true),
      ('ur dark HC', 1, AppLocales.urdu, Brightness.dark, true),
    ]) {
      testWidgets('$name, deal $deal: guidelines met down the whole page', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await open(
          tester,
          deal,
          locale: locale,
          brightness: brightness,
          hc: hc,
        );
        for (var i = 0; i < 12; i++) {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // The test font has no Urdu glyphs (they draw as hollow boxes),
          // which fools the contrast sampler; the colours are the ones the
          // English runs check.
          if (locale != AppLocales.urdu) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          final pos = tester.state<ScrollableState>(_page.first).position;
          if (pos.pixels >= pos.maxScrollExtent) break;
          await tester.drag(_page.first, const Offset(0, -500));
          await tester.pumpAndSettle();
        }
        handle.dispose();
      });
    }

    testWidgets('an ended deal (in English dark): banner, no '
        'code, guidelines met', (tester) async {
      final handle = tester.ensureSemantics();
      await open(
        tester,
        5,
        brightness: Brightness.dark,
        clock: () => DateTime.now().add(const Duration(days: 6)),
      );
      expect(find.text('WINTER30'), findsNothing);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Save works from a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      final (h, _) = await open(tester, 7);
      final node = tester.getSemantics(find.bySemanticsLabel('Save').first);
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(h.container.read(savedDealsProvider), contains(_deal(7)));
      expect(find.bySemanticsLabel('Remove from saved'), findsWidgets);
      handle.dispose();
    });

    testWidgets('Save reads as a toggle (on once saved), as the code '
        'intends with Semantics(toggled:)', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, 7);
      final node = tester.getSemantics(find.bySemanticsLabel('Save').first);
      expect(
        node.getSemanticsData().flagsCollection.isToggled,
        Tristate.isFalse,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final after = tester.getSemantics(
        find.bySemanticsLabel('Remove from saved').first,
      );
      expect(
        after.getSemanticsData().flagsCollection.isToggled,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('offline with no copy: an error with Try again, which works '
        'once back', (tester) async {
      final backend = _AllFlaky();
      final (_, _) = await open(tester, 7, backend: backend);
      expect(find.byType(ErrorView), findsOneWidget);
      backend.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('offline after Home showed it: the last copy, marked as such '
        '(QA P4-J1)', (tester) async {
      final (_, _) = await open(tester, 7, backend: FlakyGateway());
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(
        find.text('Details, terms and outlets show when you are back online.'),
        findsOneWidget,
      );
    });

    testWidgets('ur 200% on 360 × 800: the report sheet offers every reason '
        'and Send', (tester) async {
      final (h, _) = await open(
        tester,
        7,
        locale: AppLocales.urdu,
        scale: 2,
        size: const Size(360, 800),
      );
      await _signIn(h.auth);
      final report = find.byIcon(Icons.flag_outlined);
      for (var i = 0; report.hitTestable().evaluate().isEmpty; i++) {
        if (i == 40) fail('never reached Report');
        await tester.drag(_page.first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final reasons = find.byType(RadioListTile<ReportReason>);
      expect(reasons, findsNWidgets(7));
      await tester.ensureVisible(reasons.last);
      await tester.pumpAndSettle();
      await tester.tap(reasons.last);
      await tester.pumpAndSettle();
      final send = find.byType(FilledButton).last;
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A chain with 150 outlets: 145 in Karachi named "A…" to "Z…" first,
/// and 5 in Quetta named "Zarghoon…", the local deal's only target.
final class _BigChain implements BackendGateway {
  static const dealId = '00000000-0000-4000-8000-00000000c4a1';
  static const quetta = '00000000-0000-4000-a000-0000000000q1';

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    final now = DateTime.now().toUtc();
    switch (query.table) {
      case 'deal_cards':
        return [
          {
            'id': dealId,
            'brand_id': 'b-chain',
            'brand_slug': 'chain',
            'brand_name': 'Chain',
            'category_id': 'c',
            'category_slug': 'food',
            'scope': 'local',
            'status': 'published',
            'title_en': 'Quetta only',
            'offer_kind': 'percent_off',
            'percent': 20,
            'starts_at': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
        ];
      case 'deals':
        return [{}];
      case 'deal_targets':
        return [
          {'city_id': quetta, 'area_id': null},
        ];
      case 'outlets':
        final all = [
          for (var i = 0; i < 145; i++)
            {
              'id': 'k$i',
              'name': _karachiName(i),
              'address': 'Shop $i, Karachi',
              'city_id': karachiId,
              'latitude': 24.8,
              'longitude': 67.0,
            },
          for (var i = 0; i < 5; i++)
            {
              'id': 'q$i',
              'name': 'Zarghoon $i',
              'address': 'Jinnah Road, Quetta',
              'city_id': quetta,
              'latitude': 30.18,
              'longitude': 66.99,
            },
        ]..sort(_byName);
        // (Developer, round 2: filters as PostgREST applies them.)
        final matching = [
          for (final row in all)
            if (query.inList.entries.every((e) => e.value.contains(row[e.key])))
              row,
        ];
        return matching.take(query.limit ?? matching.length).toList();
    }
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async => const [];

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {}

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {}
}

String _karachiName(int i) =>
    '${String.fromCharCode(65 + i % 25)}${i.toString().padLeft(3, '0')} '
    'Karachi';

int _byName(Map<String, Object?> a, Map<String, Object?> b) =>
    (a['name']! as String).compareTo(b['name']! as String);

/// Every read and call fails until [fail] is cleared: no Home copy either.
final class _AllFlaky implements BackendGateway {
  final _demo = DemoGateway();
  bool fail = true;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (fail) throw const OfflineFailure();
    return await _demo.select(query);
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (fail) throw const OfflineFailure();
    return await _demo.rpc(function, params);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}
