// QA (sub-phase 1.2, round 2): probes of the fixes. Tests marked
// `skip: knownBug(...)` assert the expected behaviour of a bug that is still
// open in docs/qa/1.2.md; see known_bugs.dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_redactor.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';

const _redactor = LogRedactor();

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void _expectHidden(String input, String secret) {
  final out = _redactor.redact(input);
  expect(out, isNot(contains(secret)), reason: '"$input" -> "$out"');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('round-1 fixes hold (regression)', () {
    for (final (input, secret) in [
      ('phone%3D%2B923001234567', '1234567'),
      ('(+92) 300-1234567', '1234567'),
      ('‎+92 300 1234567‎', '1234567'),
      ('tel03001234567', '1234567'),
      ('#access_token=abc&refresh_token=def', 'def'),
      ('Cookie: sb-refresh-token=abc123; other=1', 'abc123'),
      ('"refresh_token" : "abc123"', 'abc123'),
      ('apiKey=abc123', 'abc123'),
      ('LatLng(lat: 24.8607, lng: 67.0011)', '8607'),
      ('lat\t=\t24.8607', '8607'),
      ('378282246310005', '8282246'),
      ('5555 5555 5555 4444', '5555 4444'),
    ]) {
      test(input, () => _expectHidden(input, secret));
    }

    test('nested sensitive keys are hidden at any depth', () {
      final out = _redactor.redactContext({
        'request': {
          'refreshToken': 'abc',
          'headers': {'Authorization': 'xyz'},
        },
        'list': [
          {'phone': '0300'},
        ],
      });
      expect(out['request'], isNot(contains('abc')));
      expect(out['request'], isNot(contains('xyz')));
      expect(out['list'], isNot(contains('0300')));
    });

    test('ordinary values are left alone', () {
      for (final text in [
        'Rs 1.299, 2.499',
        'statusCode: 500',
        'Flat 30% off 0300 to 2359',
        '2026-10-29T12:00:00.000Z',
        'pin code area 74000',
        'sku 8964000123456',
        'brand@2x.png',
      ]) {
        expect(_redactor.redact(text), text);
      }
    });

    test('input is capped, so even 5 MB redacts in well under a second', () {
      final sw = Stopwatch()..start();
      final out = _redactor.redact('x' * 5000000);
      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(out.length, lessThan(LogRedactor.maxLength + 32));
    });

    test('the worst 8 kB inputs found by QA stay under 400 ms', () {
      // Measured on this container (JIT): eyJ… repeated is the slowest
      // at ~177 ms; long word runs ~45 ms.
      for (final unit in ['eyJ', 'a', '1-', '12345-', '۰۳', 'a@b.']) {
        final input = (unit * (8190 ~/ unit.length + 1)).substring(0, 8190);
        // The fastest of three, so a busy machine (tests running side by
        // side) doesn't fail it; the budget is unchanged (QA P4-T1).
        var best = 1 << 30;
        for (var run = 0; run < 3; run++) {
          final sw = Stopwatch()..start();
          _redactor.redact(input);
          if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds;
        }
        expect(best, lessThan(400), reason: unit);
      }
    });
  });

  group('BUG-18: keyed secrets in camelCase, prefixed or escaped form', () {
    for (final (input, secret) in [
      // Dart / freezed toString() of a session-like model.
      ('Session(accessToken: opaque123, refreshToken: abc456)', 'abc456'),
      ('Session(accessToken: opaque123, refreshToken: abc456)', 'opaque123'),
      ('refreshToken: v1.abc123', 'abc123'),
      ('fcmToken=dXyZ123abc', 'dXyZ123abc'),
      ('otpCode: 482913', '482913'),
      ('X-Api-Key: abc123', 'abc123'),
      ('api-key: abc123', 'abc123'),
      ('client_secret=abc123', 'abc123'),
      ('secret_key=abc123', 'abc123'),
      ('set-cookie: session=abc123', 'abc123'),
      // A JSON body embedded in another string (escaped quotes).
      (r'{\"refresh_token\":\"abc123\"}', 'abc123'),
    ]) {
      test(input, () => _expectHidden(input, secret));
    }
  });

  group('BUG-19: keyed coordinates with quoted values or prefixed keys', () {
    for (final input in [
      '{"lat": "24.8607", "lng": "67.0011"}',
      'userLat: 24.8607, userLng: 67.0011',
      'user_lat=24.8607&user_lng=67.0011',
      'deviceLatitude=24.8607',
      'latitude%3D24.8607',
    ]) {
      test(input, () => _expectHidden(input, '8607'));
    }
  });

  group('BUG-21: database error codes are kept for debugging', () {
    for (final (input, code) in [
      (
        'PostgrestException(message: new row violates row-level security, '
            'code: 42501, details: null)',
        '42501',
      ),
      ('error code=PGRST116', 'PGRST116'),
      ('code: 23505', '23505'),
    ]) {
      test(input, () => expect(_redactor.redact(input), contains(code)));
    }

    test('an OAuth/PKCE code in a callback URL is still hidden', () {
      _expectHidden(
        'pk.salelagihai.app://login-callback?code=0b2f7a7e-8c1d-4f6e-9a3b-'
            '1c2d3e4f5a6b',
        '0b2f7a7e',
      );
    });
  });

  group('BUG-22 (S4): remaining phone layouts', () {
    for (final (input, secret) in [
      // National number without the trunk 0: what a "+92" prefix chip
      // leaves in the text field.
      ('phone input 3001234567', '1234567'),
      ('0300–1234567', '1234567'),
      ('0300 - 123 - 4567', '123 - 4567'),
      ('0300\u200B1234567', '1234567'),
      ('０３００１２３４５６７', '１２３４５６７'),
    ]) {
      test(input, () => _expectHidden(input, secret));
    }
  });

  group('BUG-23 (S4): other small redactor gaps', () {
    for (final (input, secret) in [
      ('email=ali%40gmail.com', 'ali'),
      ('card-4111111111111111', '41111111'),
      ('4111-1111-1111-1111-', '1111-1111'),
      // A JWT without its signature: the payload holds the user's claims.
      ('eyJhbGciOiJIUzI1NiJ9.eyJwaG9uZSI6IjkyMzAwIn0', 'eyJwaG9uZSI6'),
    ]) {
      test(input, () => _expectHidden(input, secret));
    }

    test('truncation never leaves part of a JWT payload', () {
      final filler = 'x ' * ((LogRedactor.maxLength - 40) ~/ 2);
      final out = _redactor.redact(
        '${filler}eyJhbGciOiJIUzI1NiJ9.'
        'eyJwaG9uZSI6IjkyMzAwMTIzNDU2NyJ9.sig',
      );
      expect(out, isNot(contains('eyJwaG9uZSI6')));
    });

    for (final key in ['refresh', 'oauthCode', 'cvc', 'dob', 'signature']) {
      test(
        'sensitive key $key',
        () => expect(LogRedactor.isSensitiveKey(key), isTrue),
      );
    }
  });

  test('BUG-24 (S4): a cyclic context value does not crash the logger', () {
    final cyclic = <String, Object?>{};
    cyclic['self'] = cyclic;
    final sink = MemoryLogSink();

    expect(
      () => AppLogger(sinks: [sink]).info('x', context: {'m': cyclic}),
      returnsNormally,
    );
    expect(sink.records, hasLength(1));
  });

  group('BUG-20: the secure store recovers after a Keystore key mismatch', () {
    /// Mimics flutter_secure_storage 11.2.0 on Android after a restore to a
    /// new phone. The wrapped data key no longer decrypts, so `initialize()`
    /// fails with a key mismatch (FlutterSecureStorage.java:421-426 →
    /// handleKeyMismatch :1016-1068), and every method, including
    /// `deleteAll`, runs `initialize()` first (FlutterSecureStoragePlugin.java
    /// :176-178). With `resetOnError: true` on a call, the plugin deletes
    /// the data and keys and then carries on; without it, the call fails,
    /// and so does every later one.
    void keyMismatchAfterRestore() {
      var broken = true;
      final stored = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureChannel, (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            final options = args['options']! as Map<Object?, Object?>;
            if (broken) {
              if (options['resetOnError'] != 'true') {
                throw PlatformException(
                  code: 'Exception',
                  message: 'Migration failed after algorithm change',
                );
              }
              broken = false;
              stored.clear();
            }
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return stored[key];
              case 'write':
                stored[key!] = args['value']! as String;
              case 'delete':
                stored.remove(key);
              case 'deleteAll':
                stored.clear();
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secureChannel, null),
      );
    }

    test('reads as signed out (passes today)', () async {
      keyMismatchAfterRestore();

      expect(await FlutterSecureStore().read(SecureKey.authSession), isNull);
    });

    test(
      'after reading as signed out, a new session can be saved and read',
      () async {
        keyMismatchAfterRestore();
        final store = FlutterSecureStore();

        expect(await store.read(SecureKey.authSession), isNull);
        await store.write(SecureKey.authSession, 'new-session');
        expect(await store.read(SecureKey.authSession), 'new-session');
      },
    );
  });
}
