// QA (sub-phase 4.9 gate): the pure parts of Settings. The mailto guard
// against hostile SUPPORT_EMAIL values, CardNumbers against the ways a
// shopper on an Urdu phone actually types a card number, AlertPrefs.fromRow
// on values Postgres can return, and the version string.
//
// "QA BUG" tests fail until the bug in docs/qa/4.9.md is fixed; S4 findings
// are skipped with their bug id (run with --dart-define=QA_KNOWN_BUGS=true).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/text/card_numbers.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/features/settings/application/app_info.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';

Map<String, String> _config(String email) => {
  'FLAVOR': 'dev',
  'APP_NAME': 'SLH',
  'SUPABASE_URL': '',
  'SUPABASE_PUBLISHABLE_KEY': '',
  'SUPPORT_EMAIL': email,
};

void main() {
  group('mailto: only one plain address, ever', () {
    const hostile = [
      'help@salelagihai.pk?cc=boss@evil.pk',
      'help@salelagihai.pk?bcc=x@evil.pk&subject=hi',
      'help@salelagihai.pk&body=hi',
      'help@salelagihai.pk,other@evil.pk',
      'help@salelagihai.pk;other@evil.pk',
      'help%40salelagihai.pk',
      'help@salelagihai.pk%0Abcc:x@evil.pk',
      'help@salelagihai.pk\nbcc:x@evil.pk',
      'help@salelagihai.pk\r\nbcc:x@evil.pk',
      'help@salelagihai.pk bcc',
      'help@salelagihai.pk#frag',
      'mailto:help@salelagihai.pk',
      'javascript:alert(1)//@salelagihai.pk',
      'help@salelagihai.pk/../x',
      ' help@salelagihai.pk',
      'help@salelagihai.pk ',
      'help@evil.pk@salelagihai.pk',
      '"a b"@salelagihai.pk',
      '@salelagihai.pk',
      'help@',
      'help@salelagihai',
      '',
    ];

    test('every hostile value is refused by LinkService and AppConfig', () {
      for (final value in hostile) {
        expect(
          UrlLauncherLinkService.mailtoUri(value),
          isNull,
          reason: 'mailtoUri(${Uri.encodeComponent(value)})',
        );
        // AppConfig trims (env files), so only the padded values differ.
        if (value.trim().isNotEmpty && value.trim() == value) {
          expect(
            () => AppConfig.fromMap(_config(value)),
            throwsA(isA<AppConfigException>()),
            reason: 'AppConfig(${Uri.encodeComponent(value)})',
          );
        }
      }
    });

    test('a plain address becomes a mailto with one recipient and no '
        'query', () {
      for (final value in [
        'help@salelagihai.pk',
        'support.team+app@mail.salelagihai.com.pk',
      ]) {
        final uri = UrlLauncherLinkService.mailtoUri(value)!;
        expect(uri.scheme, 'mailto');
        expect(uri.path, value);
        expect(uri.hasQuery, isFalse);
        expect(uri.hasFragment, isFalse);
        expect(uri.toString(), 'mailto:$value');
      }
    });

    test('QA BUG 4.9-M1: an address with capitals in its domain is a valid '
        'address', () {
      expect(
        UrlLauncherLinkService.mailtoUri('Help@SaleLagiHai.PK'),
        isNotNull,
      );
      expect(
        AppConfig.fromMap(_config('help@salelagihai.PK')).supportEmail,
        'help@salelagihai.PK',
      );
    });
  });

  group('CardNumbers', () {
    test('Western digits with the usual separators are caught', () {
      for (final text in [
        '4111111111111111',
        '4111 1111 1111 1111',
        '4111-1111-1111-1111',
        'card 4111 1111 1111 1111 exp 12/29',
        '378282246310005', // Amex, 15
      ]) {
        expect(CardNumbers.containsOne(text), isTrue, reason: text);
      }
    });

    test('ordinary report notes are not refused', () {
      for (final text in [
        'Call 0300 1234567 for the deal',
        '+92 300 1234567',
        'Rs 1,999 instead of Rs 2,499',
        'Valid 01/11/2026 to 30/11/2026',
        'Order 12345678',
        '',
      ]) {
        expect(CardNumbers.containsOne(text), isFalse, reason: text);
      }
    });

    test('QA BUG 4.9-C1: a card number typed in Urdu digits is caught', () {
      // An Urdu keyboard's number row (Extended Arabic-Indic, U+06F0..9)
      // and Arabic-Indic (U+0660..9) digits.
      expect(CardNumbers.containsOne('۴۱۱۱ ۱۱۱۱ ۱۱۱۱ ۱۱۱۱'), isTrue);
      expect(CardNumbers.containsOne('میرا کارڈ ۴۱۱۱۱۱۱۱۱۱۱۱۱۱۱۱'), isTrue);
      expect(CardNumbers.containsOne('٤١١١١١١١١١١١١١١١'), isTrue);
    });

    test('QA BUG 4.9-C2: other common separators do not hide a card '
        'number', () {
      expect(CardNumbers.containsOne('4111.1111.1111.1111'), isTrue);
      expect(CardNumbers.containsOne('4111  1111  1111  1111'), isTrue);
      expect(CardNumbers.containsOne('4111 - 1111 - 1111 - 1111'), isTrue);
    });
  });

  group('AlertPrefs.fromRow on what Postgres can return', () {
    test('times with seconds and fractions keep hour and minute', () {
      final p = AlertPrefs.fromRow(const {
        'quiet_start': '23:45:59.123456',
        'quiet_end': '00:00:00',
      });
      expect(p.quietStart, (hour: 23, minute: 45));
      expect(p.quietEnd, (hour: 0, minute: 0));
    });

    test('QA BUG 4.9-T1: an out-of-range time (Postgres time accepts 24:00) '
        'falls back to the default instead of hour 24', () {
      final p = AlertPrefs.fromRow(const {
        'quiet_start': '24:00:00',
        'quiet_end': '07:99',
      });
      expect(p.quietStart, const AlertPrefs().quietStart);
      expect(p.quietEnd, const AlertPrefs().quietEnd);
    });

    test('wireTime round-trips through fromRow for every minute', () {
      for (var h = 0; h < 24; h++) {
        for (final m in [0, 1, 29, 59]) {
          final t = (hour: h, minute: m);
          expect(
            AlertPrefs.fromRow({'quiet_start': AlertPrefs.wireTime(t)})
                .quietStart,
            t,
          );
        }
      }
    });
  });

  group('AppThemeMode', () {
    test('unknown or missing stored names fall back to system', () {
      for (final name in [null, '', 'Dark', 'sepia', 'dark ']) {
        expect(AppThemeMode.fromName(name), AppThemeMode.system, reason: name);
      }
      expect(AppThemeMode.dark.brightness?.name, 'dark');
      expect(AppThemeMode.system.brightness, isNull);
    });
  });

  group('appVersionProvider', () {
    test('no platform: empty, never an error', () async {
      // No mock values: PackageInfo goes to the (missing) plugin.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(appVersionProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(appVersionProvider.future), '');
    });

    test('no build number: only the version', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Sale Lagi Hai!',
        packageName: 'pk.salelagihai.app',
        version: '2.0.0',
        buildNumber: '',
        buildSignature: '',
      );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(appVersionProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(appVersionProvider.future), '2.0.0');
    });
  });
}
