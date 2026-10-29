import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/config/env_file.dart';

String envJson(Map<String, Object?> values) => jsonEncode(values);

const validProd = {
  'FLAVOR': 'prod',
  'APP_NAME': 'Sale Lagi Hai!',
  'SUPABASE_URL': 'https://abc.supabase.co',
  'SUPABASE_ANON_KEY': 'sb_publishable_abc',
};

void main() {
  group('validateEnvFile', () {
    test('accepts a valid file', () {
      expect(
        validateEnvFile(envJson(validProd), expectedFlavor: 'prod'),
        isEmpty,
      );
    });

    test('rejects invalid JSON', () {
      expect(validateEnvFile('{not json'), [startsWith('Not valid JSON')]);
    });

    test('rejects a non-object', () {
      expect(validateEnvFile('[1, 2]'), [
        'The file must contain a JSON object.',
      ]);
    });

    test('rejects unknown keys, catching typos', () {
      final problems = validateEnvFile(
        envJson({...validProd, 'SUPABASE_KEY': 'x'}),
      );

      expect(problems, [startsWith('Unknown key "SUPABASE_KEY"')]);
    });

    test('rejects non-string values', () {
      final problems = validateEnvFile(envJson({...validProd, 'APP_NAME': 1}));

      expect(problems, contains('"APP_NAME" must be a string.'));
    });

    test('rejects a secret key before it can be compiled in', () {
      final problems = validateEnvFile(
        envJson({...validProd, 'SUPABASE_ANON_KEY': 'sb_secret_abc'}),
      );

      expect(problems.single, contains('Never ship a secret/service_role key'));
    });

    test('rejects a flavor mismatch', () {
      final problems = validateEnvFile(
        envJson(validProd),
        expectedFlavor: 'dev',
      );

      expect(problems.single, contains('Built with --flavor dev'));
    });

    test('rejects template placeholders unless allowed', () {
      final template = envJson({
        ...validProd,
        'SUPABASE_URL': 'https://YOUR-PROD-PROJECT.supabase.co',
        'SUPABASE_ANON_KEY': 'sb_publishable_REPLACE_ME',
      });

      expect(validateEnvFile(template), hasLength(2));
      expect(
        validateEnvFile(
          envJson({
            ...validProd,
            'SUPABASE_ANON_KEY': 'sb_publishable_replace_me',
          }),
        ),
        ['"SUPABASE_ANON_KEY" still has a template placeholder value.'],
      );
      expect(validateEnvFile(template, allowPlaceholders: true), isEmpty);
    });
  });

  group('committed env templates', () {
    for (final flavor in ['dev', 'staging', 'prod']) {
      test('env/$flavor.example.json is valid for $flavor', () {
        final contents = File('env/$flavor.example.json').readAsStringSync();

        expect(
          validateEnvFile(
            contents,
            expectedFlavor: flavor,
            allowPlaceholders: true,
          ),
          isEmpty,
        );
      });
    }
  });
}
