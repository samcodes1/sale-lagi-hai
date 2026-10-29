// QA (sub-phase 1.2): bypass and over-redaction probes for LogRedactor.
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an open
// bug in docs/qa/1.2.md; see known_bugs.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/logging/log_redactor.dart';

const _redactor = LogRedactor();

/// The text must not contain any run of the digits in [digits] (ignoring
/// separators) after redaction.
void _expectNoDigitsOf(String input, String digits) {
  final out = _redactor.redact(input);
  final squashed = out.replaceAll(RegExp('[^0-9۰-۹٠-٩]'), '');
  expect(squashed, isNot(contains(digits)), reason: '"$input" -> "$out"');
}

void main() {
  group('formats that are redacted today (regression)', () {
    for (final input in [
      'tel:03001234567',
      '{"phone":"+923001234567"}',
      '+92 3001234567',
      '0092-300-1234567',
      'id 42101 1234567 1',
      'id 4210112345671',
      'ALI.KHAN@EXAMPLE.COM.PK',
      'LatLng(24.8607, 67.0011)',
      'maps @24.8607,67.0011,15z',
      '-33.8650,-151.2094',
      'apikey: sb_publishable_abc',
    ]) {
      test(input, () => expect(_redactor.redact(input), isNot(input)));
    }
  });

  group('ordinary deal text is left alone (regression)', () {
    final rnd = Random(12);
    String hex(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();

    test('random v4 UUIDs with hex digits are never redacted', () {
      for (var i = 0; i < 500; i++) {
        final segments = [hex(8), hex(4), '4${hex(3)}', 'a${hex(3)}', hex(12)];
        // Runs of all-decimal segments can look like a card number: that
        // is BUG-14, tested below, so only check UUIDs with a letter in
        // every segment here.
        if (segments.any((s) => !s.contains(RegExp('[a-f]')))) continue;
        final uuid = segments.join('-');
        expect(_redactor.redact('deal $uuid'), 'deal $uuid');
      }
    });

    for (final text in [
      'Rs 1,299',
      'Rs 12,500,000',
      'Flat 50% off, 3 items',
      '10:30 to 23:59, 31.10.2026',
      'code SALE2026',
      'NTN 1234567-8',
      'price 1299.000, 2499.000',
      'follow @salelagihai',
    ]) {
      test(text, () => expect(_redactor.redact(text), text));
    }
  });

  group('BUG-1: common Pakistani phone formats are redacted', () {
    for (final input in [
      // The format Supabase Auth stores (E.164 without "+").
      'user.phone 923001234567',
      '92 300 1234567',
      '0300-123-4567',
      '0300 123 4567',
      '+92-300-123-4567',
      '+92(300)1234567',
      '+92 (300) 1234567',
      '0300.1234567',
      // URL-encoded "+" in a query string.
      'phone=%2B923001234567&channel=sms',
    ]) {
      test(input, () => _expectNoDigitsOf(input, '1234567'));
    }
  });

  group('BUG-2: Urdu / Arabic-Indic digits are redacted', () {
    for (final (input, digits) in [
      ('OTP sent to ۰۳۰۰۱۲۳۴۵۶۷', '۱۲۳۴۵۶۷'),
      ('OTP sent to ٠٣٠٠١٢٣٤٥٦٧', '١٢٣٤٥٦٧'),
      ('+۹۲۳۰۰۱۲۳۴۵۶۷', '۱۲۳۴۵۶۷'),
      ('CNIC ۴۲۱۰۱-۱۲۳۴۵۶۷-۱', '۱۲۳۴۵۶۷'),
      ('at ۲۴٫۸۶۰۷, ۶۷٫۰۰۱۱', '۸۶۰۷'),
    ]) {
      test(input, () => _expectNoDigitsOf(input, digits));
    }
  });

  group('BUG-3: credentials that are not JWTs are redacted', () {
    for (final (input, secret) in [
      ('refresh_token=v1.MRjVfQZ3Kx9&type=x', 'MRjVfQZ3Kx9'),
      ('{"refresh_token":"abcd1234efgh"}', 'abcd1234efgh'),
      ('access_token=opaqueAbc123&expires_in=3600', 'opaqueAbc123'),
      ('verify otp=482913', '482913'),
      ('pk.salelagihai.app://login-callback?code=a1b2c3-d4e5', 'a1b2c3-d4e5'),
      ('Authorization: Basic dXNlcjpwYXNz', 'dXNlcjpwYXNz'),
      (
        'fcm dXyZ123:APA91bHPRgkF3JUikC4ENAHEeMrd41Zxv3hVZjC9KtT8OvPVGJ-hQ',
        'APA91bHPRgkF3JUikC4ENAHEeMrd41Zxv3hVZjC9KtT8OvPVGJ',
      ),
    ]) {
      test(
        input,
        () => expect(_redactor.redact(input), isNot(contains(secret))),
      );
    }

    test('sensitive keys nested inside a context value are hidden', () {
      final out = _redactor.redactContext({
        'request': {'token': 'abc123', 'refresh_token': 'zzz999'},
      });
      expect(out['request'], isNot(contains('abc123')));
      expect(out['request'], isNot(contains('zzz999')));
    });
  });

  group('BUG-4: sensitive context keys are recognised', () {
    for (final key in [
      'FCMToken',
      'APIKey',
      'OTPCode',
      'apikey',
      'accesstoken',
      'phonenumber',
      'pin',
      'passcode',
      'credentials',
      'fullName',
      'cellNumber',
      'telephone',
      'coords',
      'position',
    ]) {
      test(key, () => expect(LogRedactor.isSensitiveKey(key), isTrue));
    }
  });

  group('BUG-5: precise coordinates in other layouts are redacted', () {
    for (final input in [
      'lat=24.8607&lng=67.0011',
      '{"lat":24.8607,"lng":67.0011}',
      'at 24.8607 67.0011',
      'at 24.8607;67.0011',
      'lat 24.86073',
    ]) {
      test(input, () => _expectNoDigitsOf(input, '8607'));
    }
  });

  group('BUG-6: redaction cost is linear', () {
    test('ordinary prose of 18 kB redacts fast (passes today)', () {
      final prose = 'The quick brown fox jumps over the lazy dog. ' * 400;
      final sw = Stopwatch()..start();
      _redactor.redact(prose);
      expect(sw.elapsedMilliseconds, lessThan(200));
    });

    test('a 20 kB base64url blob redacts in under 200 ms', () {
      final rnd = Random(1);
      final blob = base64Url
          .encode(List.generate(15000, (_) => rnd.nextInt(256)))
          .replaceAll('=', '');
      final sw = Stopwatch()..start();
      _redactor.redact(blob);
      // Measured: ~3.1 s (JIT) because the email rule is O(n²).
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  group('BUG-14 (S4): ordinary numbers are not over-redacted', () {
    for (final text in [
      'sku 8964000123456',
      'deal 00000000-0000-4000-8000-000000000000',
      'Rs 1.299, 2.499',
      'asset icon@2x.png',
    ]) {
      test(text, () => expect(_redactor.redact(text), text));
    }

    // Accepted trade-off (developer decision, see docs/qa/1.2.md): a
    // 13-digit number starting 1-7 is indistinguishable from an unhyphenated
    // CNIC, so it is redacted. Asserted, so a change that starts leaking
    // CNICs fails here. The logger records times as DateTime anyway.
    test('accepted: a 13-digit number starting 1-7 is redacted as a CNIC', () {
      expect(_redactor.redact('savedAt 1761739200000 ms'), 'savedAt [cnic] ms');
    });
  });
}
