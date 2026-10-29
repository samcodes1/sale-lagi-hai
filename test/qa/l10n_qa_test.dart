// QA tests for sub-phase 1.4 (Localization & RTL), written by the QA
// engineer. Tests marked `skip: knownBug(...)` assert the expected
// behaviour of an open bug (docs/qa/1.4.md); run them with
// `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';

import '../helpers/fakes.dart';
import 'known_bugs.dart';

final _now = DateTime(2026, 10, 29, 12); // Thursday noon, local time

void main() {
  late AppLocalizations en;
  late AppLocalizations ur;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ur');
    en = await AppLocalizations.delegate.load(AppLocales.english);
    ur = await AppLocalizations.delegate.load(AppLocales.urdu);
  });

  DealTimeLabels labels(
    AppLocalizations l10n,
    Locale locale, {
    bool urduDigits = false,
  }) =>
      DealTimeLabels(l10n, AppFormatters(l10n, locale, urduDigits: urduDigits));

  group('expiry boundaries', () {
    test('under a minute left never reads "Ends in 0 hours"', () {
      final endsAt = _now.add(const Duration(seconds: 30));
      expect(
        labels(en, AppLocales.english).expiry(endsAt, now: _now),
        'Ends in 1 hour',
      );
      expect(
        labels(ur, AppLocales.urdu).expiry(endsAt, now: _now),
        '1 گھنٹے میں ختم',
      );
    });

    test('one second left is not "Expired" and 1 minute is "1 hour"', () {
      expect(
        labels(
          en,
          AppLocales.english,
        ).expiry(_now.add(const Duration(minutes: 1)), now: _now),
        'Ends in 1 hour',
      );
    });

    test('exactly 6 hours left switches to the calendar wording', () {
      expect(
        labels(
          en,
          AppLocales.english,
        ).expiry(_now.add(const Duration(hours: 6)), now: _now),
        'Ends today',
      );
    });

    test('3 calendar days is relative, 4 is the date (72h policy)', () {
      final l = labels(en, AppLocales.english);
      expect(
        l.expiry(DateTime(2026, 11, 1, 23, 59), now: _now),
        'Ends in 3 days',
      );
      expect(l.expiry(DateTime(2026, 11, 2, 0, 1), now: _now), 'Ends 2 Nov');
    });

    test('a UTC end time is compared in local time', () {
      final l = labels(en, AppLocales.english);
      final endsAtUtc = _now.add(const Duration(days: 1, hours: 2)).toUtc();
      expect(l.expiry(endsAtUtc, now: _now), 'Ends tomorrow');
    });

    test('a year boundary still counts calendar days', () {
      final l = labels(en, AppLocales.english);
      expect(
        l.expiry(DateTime(2027, 1, 1, 10), now: DateTime(2026, 12, 31, 9)),
        'Ends tomorrow',
      );
    });
  });

  group('verified and updated boundaries', () {
    test('59 minutes, 1 hour, 23 hours, 1 day', () {
      final l = labels(en, AppLocales.english);
      String v(Duration d) => l.verified(_now.subtract(d), now: _now);
      expect(
        v(const Duration(minutes: 59, seconds: 59)),
        'Verified 59 minutes ago',
      );
      expect(v(const Duration(hours: 1)), 'Verified 1 hour ago');
      expect(
        v(const Duration(hours: 23, minutes: 59)),
        'Verified 23 hours ago',
      );
      expect(v(const Duration(days: 1)), 'Verified yesterday');
      expect(v(const Duration(days: 40)), 'Verified 40 days ago');
    });

    test('far-future timestamps (big clock skew) read "just now"', () {
      final l = labels(en, AppLocales.english);
      expect(
        l.verified(_now.add(const Duration(days: 3)), now: _now),
        'Verified just now',
      );
      expect(
        l.updated(_now.add(const Duration(hours: 5)), now: _now),
        'Updated just now',
      );
    });
  });

  group('Urdu digits option', () {
    final urduDigit = RegExp('[۰-۹]');
    final westernDigit = RegExp('[0-9]');

    test('numbers, prices and dates map', () {
      final f = AppFormatters(ur, AppLocales.urdu, urduDigits: true);
      expect(f.price(2999), '۲,۹۹۹ روپے');
      expect(f.shortDate(DateTime(2026, 11, 3)), '۳ نومبر');
      expect(
        labels(
          ur,
          AppLocales.urdu,
          urduDigits: true,
        ).expiry(DateTime(2026, 11, 3), now: _now),
        '۳ نومبر کو ختم',
      );
    });

    test(
      'the discount badge and relative times use Urdu digits too',
      skip: knownBug('1.4 BUG-2') != false,
      () {
        final f = AppFormatters(ur, AppLocales.urdu, urduDigits: true);
        final l = labels(ur, AppLocales.urdu, urduDigits: true);
        final texts = [
          f.discount(40),
          l.expiry(_now.add(const Duration(hours: 2)), now: _now),
          l.expiry(_now.add(const Duration(days: 3)), now: _now),
          l.verified(_now.subtract(const Duration(minutes: 5)), now: _now),
          l.updated(_now.subtract(const Duration(hours: 3)), now: _now),
        ];
        for (final t in texts) {
          expect(t, isNot(contains(westernDigit)), reason: t);
          expect(t, contains(urduDigit), reason: t);
        }
      },
    );
  });

  group('bidi', () {
    final urArb = jsonDecode(
      File('lib/l10n/app_ur.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('the Urdu discount badge is an LTR isolate', () {
      expect(urArb['discountBadge'], startsWith('\u2066'));
      expect(urArb['discountBadge'], endsWith('\u2069'));
      // Isolates are balanced in every Urdu string.
      for (final MapEntry(:key, :value) in urArb.entries) {
        if (key.startsWith('@') || value is! String) continue;
        final opens = RegExp('[\u2066\u2067\u2068]').allMatches(value).length;
        final closes = '\u2069'.allMatches(value).length;
        expect(opens, closes, reason: key);
      }
    });

    testWidgets('"-40%" keeps the sign in front in an RTL paragraph', (
      tester,
    ) async {
      // Lay the badge text out RTL and check the glyph for "-" sits left of
      // the digits (visual order), as an LTR reader expects.
      final text = AppFormatters(ur, AppLocales.urdu).discount(40);
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      final minus = text.indexOf('-');
      final four = text.indexOf('4');
      final xMinus = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: minus, extentOffset: minus + 1),
          )
          .single
          .left;
      final xFour = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: four, extentOffset: four + 1),
          )
          .single
          .left;
      expect(xMinus, lessThan(xFour));
      painter.dispose();
    });
  });

  group('bidi: percentages inside Urdu sentences', () {
    // Visual x of a character when [text] is laid out right to left.
    double x(TextPainter p, String text, String char) {
      final i = text.indexOf(char);
      return p
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .single
          .left;
    }

    for (final (name, build) in [
      ('Up to N% off', (AppLocalizations l) => l.upToPercentOff(30)),
      ('Flat N% off', (AppLocalizations l) => l.flatPercentOff(30)),
    ]) {
      testWidgets('$name: "30%" reads 3-0-% left to right in Urdu', (
        tester,
      ) async {
        final text = build(ur);
        final p = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
          textDirection: TextDirection.rtl,
        )..layout();
        expect(x(p, text, '3'), lessThan(x(p, text, '0')), reason: text);
        expect(x(p, text, '0'), lessThan(x(p, text, '%')), reason: text);
        p.dispose();
      });
    }
  });

  group('locale persistence end to end', () {
    test('a choice survives a restart through loadStartupSettings', () async {
      final store = InMemoryKeyValueStore();
      final logger = AppLogger(sinks: []);
      final first = ProviderContainer(
        overrides: [
          onboardedShopper,
          keyValueStoreProvider.overrideWithValue(store),
          deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
          loggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(first.dispose);
      await first
          .read(localeControllerProvider.notifier)
          .select(const Locale('ur', 'PK'));

      final settings = await loadStartupSettings(
        logger,
        openStore: () => store,
      );
      expect(settings.locale, AppLocales.urdu);

      final second = ProviderContainer(
        overrides: [
          onboardedShopper,
          savedLocaleProvider.overrideWithValue(settings.locale),
          deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
        ],
      );
      addTearDown(second.dispose);
      expect(second.read(localeControllerProvider), AppLocales.urdu);
    });

    test(
      'rapid switching ends on the last choice, in memory and saved',
      () async {
        final store = InMemoryKeyValueStore();
        final c = ProviderContainer(
          overrides: [
            onboardedShopper,
            keyValueStoreProvider.overrideWithValue(store),
            deviceLocaleProvider.overrideWithValue(AppLocales.english),
            loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          ],
        );
        addTearDown(c.dispose);
        final n = c.read(localeControllerProvider.notifier);
        await Future.wait([
          for (var i = 0; i < 9; i++)
            n.select(i.isEven ? AppLocales.urdu : AppLocales.english),
        ]);
        expect(c.read(localeControllerProvider), AppLocales.urdu);
        expect(await store.getString(localeStorageKey), 'ur');
      },
    );

    testWidgets('a saved Urdu choice renders RTL on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardedShopper,
            appConfigProvider.overrideWithValue(
              const AppConfig(
                flavor: Flavor.dev,
                appName: 'SLH',
                supabaseUrl: '',
                supabasePublishableKey: '',
              ),
            ),
            savedLocaleProvider.overrideWithValue(AppLocales.urdu),
            deviceLocaleProvider.overrideWithValue(AppLocales.english),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          ],
          child: const App(),
        ),
      );
      // One frame only: no flash of English.
      await tester.pump();
      final home = find.byType(HomeScreen);
      expect(home, findsOneWidget);
      expect(Directionality.of(tester.element(home)), TextDirection.rtl);
      expect(Localizations.localeOf(tester.element(home)), AppLocales.urdu);
      expect(find.text(ur.navHome), findsOneWidget);
      expect(
        MaterialLocalizations.of(tester.element(home)).backButtonTooltip,
        isNot('Back'),
      );
    });
  });
}
