import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

/// Builds an unsigned JWT-shaped key with the given `role` claim.
String fakeJwt(String role) {
  String encode(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'role': role, 'iss': 'supabase'})}.signature';
}

Map<String, String> validValues({
  String flavor = 'prod',
  String url = 'https://abc.supabase.co',
  String key = 'sb_publishable_abc123',
}) => {
  'FLAVOR': flavor,
  'APP_NAME': 'Sale Lagi Hai!',
  'SUPABASE_URL': url,
  'SUPABASE_ANON_KEY': key,
};

Matcher throwsConfigProblem(String fragment) => throwsA(
  isA<AppConfigException>().having(
    (e) => e.problems.join('\n'),
    'problems',
    contains(fragment),
  ),
);

void main() {
  group('AppConfig.fromMap', () {
    test('parses a valid prod config', () {
      final config = AppConfig.fromMap(validValues());

      expect(config.flavor, Flavor.prod);
      expect(config.appName, 'Sale Lagi Hai!');
      expect(config.supabaseUrl, 'https://abc.supabase.co');
      expect(config.hasBackend, isTrue);
    });

    test('trims whitespace around values', () {
      final config = AppConfig.fromMap(const {
        'FLAVOR': ' staging ',
        'APP_NAME': ' SLH Staging ',
        'SUPABASE_URL': ' https://abc.supabase.co ',
        'SUPABASE_ANON_KEY': ' sb_publishable_x ',
      });

      expect(config.flavor, Flavor.staging);
      expect(config.appName, 'SLH Staging');
      expect(config.supabaseAnonKey, 'sb_publishable_x');
    });

    test('allows a dev build without a backend', () {
      final config = AppConfig.fromMap(
        validValues(flavor: 'dev', url: '', key: ''),
      );

      expect(config.flavor, Flavor.dev);
      expect(config.hasBackend, isFalse);
    });

    test('accepts a legacy anon JWT key', () {
      final config = AppConfig.fromMap(validValues(key: fakeJwt('anon')));

      expect(config.supabaseAnonKey, fakeJwt('anon'));
    });

    test('rejects a missing flavor', () {
      expect(
        () => AppConfig.fromMap(validValues(flavor: '')),
        throwsConfigProblem('FLAVOR is missing'),
      );
    });

    test('rejects an unknown flavor', () {
      expect(
        () => AppConfig.fromMap(validValues(flavor: 'production')),
        throwsConfigProblem('"production" is not one of dev, staging, prod'),
      );
    });

    test('rejects a missing app name', () {
      expect(
        () => AppConfig.fromMap({...validValues(), 'APP_NAME': '  '}),
        throwsConfigProblem('APP_NAME is missing'),
      );
    });

    test('requires a backend for staging and prod', () {
      for (final flavor in ['staging', 'prod']) {
        expect(
          () =>
              AppConfig.fromMap(validValues(flavor: flavor, url: '', key: '')),
          throwsA(
            isA<AppConfigException>().having(
              (e) => e.problems,
              'problems',
              containsAll([
                'SUPABASE_URL is missing.',
                'SUPABASE_ANON_KEY is missing.',
              ]),
            ),
          ),
          reason: flavor,
        );
      }
    });

    test('rejects a non-https Supabase URL', () {
      for (final url in [
        'http://abc.supabase.co',
        'abc.supabase.co',
        'https://',
      ]) {
        expect(
          () => AppConfig.fromMap(validValues(url: url)),
          throwsConfigProblem('must be a valid https:// URL'),
          reason: url,
        );
      }
    });

    test('rejects a new-format secret key', () {
      expect(
        () => AppConfig.fromMap(validValues(key: 'sb_secret_abc123')),
        throwsConfigProblem('secret/service_role key'),
      );
    });

    test('rejects a legacy service_role JWT key', () {
      expect(
        () => AppConfig.fromMap(validValues(key: fakeJwt('service_role'))),
        throwsConfigProblem('secret/service_role key'),
      );
    });

    test('rejects a malformed three-part key cleanly', () {
      expect(
        () => AppConfig.fromMap(validValues(key: 'a.%%%.c')),
        throwsConfigProblem('must be the publishable key'),
      );
    });

    test('only allows publishable keys and anon JWTs', () {
      for (final key in [
        fakeJwt('authenticated'),
        fakeJwt('supabase_admin'),
        'sk_live_51Habcdef',
        'sb_publishable_',
        'Bearer sb_publishable_x',
      ]) {
        expect(
          () => AppConfig.fromMap(validValues(key: key)),
          throwsConfigProblem('must be the publishable key'),
          reason: key,
        );
      }
    });

    test('requires URL and key together, even in dev', () {
      expect(
        () => AppConfig.fromMap(validValues(flavor: 'dev', key: '')),
        throwsConfigProblem('must be set together'),
      );
      expect(
        () => AppConfig.fromMap(
          validValues(flavor: 'dev', url: '', key: 'sb_publishable_x'),
        ),
        throwsConfigProblem('must be set together'),
      );
    });

    test('reports every problem at once', () {
      try {
        AppConfig.fromMap(const {});
        fail('Expected AppConfigException');
      } on AppConfigException catch (e) {
        expect(e.problems, hasLength(2));
        expect(e.toString(), startsWith('Invalid app configuration:'));
      }
    });
  });

  group('verifyBuildFlavor', () {
    final config = AppConfig.fromMap(validValues());

    test('passes when there is no native flavor (web, tests)', () {
      expect(() => config.verifyBuildFlavor(null), returnsNormally);
    });

    test('passes when the native flavor matches', () {
      expect(() => config.verifyBuildFlavor('prod'), returnsNormally);
    });

    test('fails when the native flavor and config differ', () {
      final devConfig = AppConfig.fromMap(
        validValues(flavor: 'dev', url: '', key: ''),
      );

      expect(
        () => devConfig.verifyBuildFlavor('prod'),
        throwsConfigProblem(
          'Built with --flavor prod but the config is for dev. '
          'Use --dart-define-from-file=env/prod.json.',
        ),
      );
    });
  });

  test('toString never contains the key', () {
    final config = AppConfig.fromMap(validValues(key: 'sb_publishable_TOPKEY'));

    expect(config.toString(), isNot(contains('TOPKEY')));
    expect(config.toString(), isNot(contains('supabase.co')));
    expect(config.toString(), contains('prod'));
  });

  test('fromEnvironment fails clearly when no config was compiled in', () {
    // Tests run without --dart-define-from-file, so FLAVOR is empty.
    expect(AppConfig.fromEnvironment, throwsConfigProblem('FLAVOR is missing'));
  });
}
