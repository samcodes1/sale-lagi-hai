import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ur;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ur');
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ur = await AppLocalizations.delegate.load(const Locale('ur'));
  });

  group('AppFormatters', () {
    test('prices use Western grouping in both languages', () {
      expect(AppFormatters(en, const Locale('en')).price(2999), 'Rs 2,999');
      expect(AppFormatters(en, const Locale('en')).price(12500), 'Rs 12,500');
      expect(AppFormatters(ur, const Locale('ur')).price(2999), '2,999 روپے');
    });

    test('Urdu digits are opt-in', () {
      final format = AppFormatters(ur, const Locale('ur'), urduDigits: true);

      expect(format.price(2999), '۲,۹۹۹ روپے');
      expect(format.number(1234567), '۱,۲۳۴,۵۶۷');
    });

    test('toUrduDigits maps every digit and nothing else', () {
      expect(toUrduDigits('0123456789'), '۰۱۲۳۴۵۶۷۸۹');
      expect(toUrduDigits('Rs 40% off'), 'Rs ۴۰% off');
    });

    test('price change reads naturally for screen readers', () {
      expect(
        AppFormatters(en, const Locale('en')).priceChange(was: 4999, now: 2999),
        'was Rs 4,999, now Rs 2,999',
      );
      expect(
        AppFormatters(ur, const Locale('ur')).priceChange(was: 4999, now: 2999),
        'پہلے 4,999 روپے، اب 2,999 روپے',
      );
    });

    test('discount badges keep the minus sign in front, even in RTL', () {
      expect(AppFormatters(en, const Locale('en')).discount(40), '-40%');
      // Wrapped in an LTR isolate so bidi cannot move the sign.
      expect(
        AppFormatters(ur, const Locale('ur')).discount(40),
        '\u2066-40%\u2069',
      );
    });

    test('short dates are localized', () {
      final date = DateTime(2026, 11, 3);

      expect(AppFormatters(en, const Locale('en')).shortDate(date), '3 Nov');
      expect(AppFormatters(ur, const Locale('ur')).shortDate(date), '3 نومبر');
      expect(
        AppFormatters(ur, const Locale('ur'), urduDigits: true).shortDate(date),
        '۳ نومبر',
      );
    });

    testWidgets('of(context) uses the context locale', (tester) async {
      late AppFormatters format;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('ur'),
          delegates: const [
            AppLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              format = AppFormatters.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(format.locale, const Locale('ur'));
      expect(format.price(10), '10 روپے');
    });
  });

  group('DealTimeLabels.expiry', () {
    final now = DateTime(2026, 10, 29, 12); // a Thursday, noon
    DealTimeLabels labels(AppLocalizations l10n, String code) =>
        DealTimeLabels(l10n, AppFormatters(l10n, Locale(code)));

    final cases = <String, (DateTime?, String, String)>{
      'no end date': (null, 'Ongoing', 'جاری ہے'),
      'already ended': (
        now.subtract(const Duration(minutes: 1)),
        'Expired',
        'ختم ہو گئی',
      ),
      'ends exactly now': (now, 'Expired', 'ختم ہو گئی'),
      '20 minutes left rounds up to 1 hour': (
        now.add(const Duration(minutes: 20)),
        'Ends in 1 hour',
        '1 گھنٹے میں ختم',
      ),
      '90 minutes left rounds up to 2 hours': (
        now.add(const Duration(minutes: 90)),
        'Ends in 2 hours',
        '2 گھنٹوں میں ختم',
      ),
      'later today (8 hours)': (
        now.add(const Duration(hours: 8)),
        'Ends today',
        'آج ختم',
      ),
      'tomorrow evening': (
        DateTime(2026, 10, 30, 20),
        'Ends tomorrow',
        'کل ختم',
      ),
      'in 3 calendar days': (
        DateTime(2026, 11, 1, 9),
        'Ends in 3 days',
        '3 دن میں ختم',
      ),
      'further out shows the date': (
        DateTime(2026, 11, 3),
        'Ends 3 Nov',
        '3 نومبر کو ختم',
      ),
    };

    for (final MapEntry(key: name, value: (endsAt, english, urdu))
        in cases.entries) {
      test(name, () {
        expect(labels(en, 'en').expiry(endsAt, now: now), english);
        expect(labels(ur, 'ur').expiry(endsAt, now: now), urdu);
      });
    }

    test('5 hours 59 minutes left is still "in N hours"', () {
      expect(
        labels(
          en,
          'en',
        ).expiry(now.add(const Duration(hours: 5, minutes: 59)), now: now),
        'Ends in 6 hours',
      );
    });

    test('a deal ending just after midnight late at night is "tomorrow"', () {
      final lateNight = DateTime(2026, 10, 29, 17);
      expect(
        labels(en, 'en').expiry(DateTime(2026, 10, 30, 0, 30), now: lateNight),
        'Ends tomorrow',
      );
    });
  });

  group('DealTimeLabels.verified and updated', () {
    final now = DateTime(2026, 10, 29, 12);
    late DealTimeLabels labelsEn;
    late DealTimeLabels labelsUr;

    setUp(() {
      labelsEn = DealTimeLabels(en, AppFormatters(en, const Locale('en')));
      labelsUr = DealTimeLabels(ur, AppFormatters(ur, const Locale('ur')));
    });

    test('minutes, hours and days', () {
      expect(labelsEn.verified(now, now: now), 'Verified just now');
      expect(
        labelsEn.verified(now.subtract(const Duration(minutes: 1)), now: now),
        'Verified 1 minute ago',
      );
      expect(
        labelsEn.verified(now.subtract(const Duration(minutes: 45)), now: now),
        'Verified 45 minutes ago',
      );
      expect(
        labelsEn.verified(now.subtract(const Duration(hours: 3)), now: now),
        'Verified 3 hours ago',
      );
      expect(
        labelsEn.verified(now.subtract(const Duration(days: 1)), now: now),
        'Verified yesterday',
      );
      expect(
        labelsEn.verified(now.subtract(const Duration(days: 4)), now: now),
        'Verified 4 days ago',
      );
      expect(
        labelsUr.verified(now.subtract(const Duration(hours: 3)), now: now),
        '3 گھنٹے پہلے تصدیق ہوئی',
      );
    });

    test('a time in the future (clock skew) reads as just now', () {
      expect(
        labelsEn.verified(now.add(const Duration(minutes: 5)), now: now),
        'Verified just now',
      );
      expect(
        labelsEn.updated(now.add(const Duration(minutes: 5)), now: now),
        'Updated just now',
      );
    });

    test('updated uses its own wording', () {
      expect(
        labelsEn.updated(now.subtract(const Duration(hours: 2)), now: now),
        'Updated 2 hours ago',
      );
      expect(
        labelsEn.updated(now.subtract(const Duration(minutes: 1)), now: now),
        'Updated 1 minute ago',
      );
      expect(
        labelsEn.updated(now.subtract(const Duration(days: 2)), now: now),
        'Updated 2 days ago',
      );
      expect(
        labelsUr.updated(now.subtract(const Duration(days: 1)), now: now),
        'کل اپ ڈیٹ ہوا',
      );
    });
  });

  group('FailureMessage', () {
    const failures = <AppFailure>[
      OfflineFailure(),
      TimeoutFailure(),
      ServerFailure(statusCode: 503),
      UnauthorizedFailure(),
      ForbiddenFailure(),
      NotFoundFailure(),
      ValidationFailure(),
      RateLimitedFailure(),
      StorageFailure(),
      UnexpectedFailure(),
    ];

    test('every failure has its own message in both languages', () {
      for (final l10n in [en, ur]) {
        final messages = failures.map((f) => f.message(l10n)).toList();
        expect(messages.toSet(), hasLength(failures.length));
        expect(messages, everyElement(isNotEmpty));
      }
    });

    test('the message never includes the technical cause', () {
      const failure = UnexpectedFailure(cause: 'SocketException 03001234567');

      expect(failure.message(en), isNot(contains('Socket')));
      expect(failure.message(en), 'Something went wrong. Try again.');
    });
  });
}
