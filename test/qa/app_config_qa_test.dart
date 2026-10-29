// QA (sub-phase 1.1): extra edge cases for AppConfig.fromMap, focused on
// secret-key detection and URL validation.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

String _b64(Object json, {bool pad = false, bool standard = false}) {
  final bytes = utf8.encode(jsonEncode(json));
  var s = standard ? base64.encode(bytes) : base64Url.encode(bytes);
  if (!pad) s = s.replaceAll('=', '');
  return s;
}

String _jwt(Map<String, Object?> claims, {bool pad = false}) =>
    '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
    '${_b64(claims, pad: pad)}.sig';

Map<String, String> _values(String key, {String flavor = 'prod'}) => {
  'FLAVOR': flavor,
  'APP_NAME': 'Sale Lagi Hai!',
  'SUPABASE_URL': 'https://abc.supabase.co',
  'SUPABASE_ANON_KEY': key,
};

bool _rejectedAsSecret(String key, {String flavor = 'prod'}) {
  try {
    AppConfig.fromMap(_values(key, flavor: flavor));
    return false;
  } on AppConfigException catch (e) {
    return e.problems.any((p) => p.contains('secret/service_role'));
  }
}

void main() {
  group('secret-key detection: keys that must be rejected', () {
    test('sb_secret_ key with surrounding whitespace/newline', () {
      expect(_rejectedAsSecret('  sb_secret_abc\n'), isTrue);
    });

    test('service_role JWT with base64 padding in the payload', () {
      expect(
        _rejectedAsSecret(_jwt({'role': 'service_role'}, pad: true)),
        isTrue,
      );
    });

    test('service_role JWT whose payload needs URL-safe chars', () {
      // Long claims so the encoding contains '-' or '_'.
      final key = _jwt({
        'role': 'service_role',
        'iss': 'supabase',
        'ref': '???>>>~~~???>>>~~~',
        'iat': 1700000000,
        'exp': 2000000000,
      });
      expect(_rejectedAsSecret(key), isTrue);
    });

    test('service_role JWT pasted with a "Bearer " prefix', () {
      expect(
        _rejectedAsSecret('Bearer ${_jwt({'role': 'service_role'})}'),
        isTrue,
      );
    });

    test('secret key in a dev build is still rejected', () {
      expect(_rejectedAsSecret('sb_secret_abc', flavor: 'dev'), isTrue);
    });

    test('the error message never echoes the key itself', () {
      try {
        AppConfig.fromMap(_values('sb_secret_TOPSECRET'));
        fail('expected AppConfigException');
      } on AppConfigException catch (e) {
        expect(e.toString(), isNot(contains('TOPSECRET')));
      }
    });
  });

  group('secret-key detection: malformed input is rejected, not a crash', () {
    for (final key in [
      'a.b.c',
      'a..c',
      '..',
      'a.%%%.c',
      'a.Zm9v.c', // decodes to "foo": not JSON
      'a.${_b64([1, 2, 3])}.c', // JSON array, not an object
      'a.${_b64('service_role')}.c', // JSON string, not an object
      'a.${_b64({'role': null})}.c',
      'a.${_b64({'role': 42})}.c',
      'a./w.c', // invalid UTF-8 after decoding
      'a.abcde.c', // invalid base64 length
      'x' * 100000,
      '${'a' * 5000}.${'b' * 5000}.${'c' * 5000}',
    ]) {
      final label = key.length > 40 ? '${key.substring(0, 40)}…' : key;
      test('rejects with AppConfigException: $label', () {
        expect(
          () => AppConfig.fromMap(_values(key)),
          throwsA(isA<AppConfigException>()),
        );
      });
    }
  });

  group('key check is an allowlist (fix for QA BUG-3)', () {
    test('a JWT with a non-anon role (supabase_admin) is rejected', () {
      expect(_rejectedAsSecret(_jwt({'role': 'supabase_admin'})), isTrue);
    });

    test('an arbitrary non-Supabase secret is rejected', () {
      expect(_rejectedAsSecret('sk_live_51Habcdef'), isTrue);
    });

    test('an anon JWT with base64 padding is accepted', () {
      expect(_rejectedAsSecret(_jwt({'role': 'anon'}, pad: true)), isFalse);
    });

    test('the example placeholder key/URL pass validation for prod', () {
      final config = AppConfig.fromMap(const {
        'FLAVOR': 'prod',
        'APP_NAME': 'Sale Lagi Hai!',
        'SUPABASE_URL': 'https://YOUR-PROD-PROJECT.supabase.co',
        'SUPABASE_ANON_KEY': 'sb_publishable_REPLACE_ME',
      });
      expect(config.flavor, Flavor.prod);
    });
  });

  group('URL validation', () {
    for (final url in [
      'ftp://abc.supabase.co',
      'https:abc.supabase.co',
      'https://:443',
      'https://abc.supabase.co:notaport',
      'javascript:alert(1)',
      'file:///etc/passwd',
    ]) {
      test('rejects $url', () {
        expect(
          () => AppConfig.fromMap({
            ..._values('sb_publishable_x'),
            'SUPABASE_URL': url,
          }),
          throwsA(isA<AppConfigException>()),
        );
      });
    }

    test('accepts an upper-case scheme', () {
      final config = AppConfig.fromMap({
        ..._values('sb_publishable_x'),
        'SUPABASE_URL': 'HTTPS://abc.supabase.co',
      });
      expect(config.hasBackend, isTrue);
    });
  });

  group('flavor parsing', () {
    test('rejects a differently-cased flavor with a clear message', () {
      expect(
        () => AppConfig.fromMap({
          ..._values('sb_publishable_x'),
          'FLAVOR': 'Prod',
        }),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.problems.join(),
            'problems',
            contains('"Prod" is not one of'),
          ),
        ),
      );
    });
  });
}
