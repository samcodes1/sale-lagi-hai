// QA (sub-phase 1.1): the committed env/*.example.json files are what CI
// builds with, but no test validated them. These tests check that every
// example parses through AppConfig, carries exactly the keys AppConfig reads,
// and agrees with the Android flavor (app name) in build.gradle.kts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

const _expectedKeys = {
  'FLAVOR',
  'APP_NAME',
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
};

Map<String, String> _readExample(Flavor flavor) {
  final file = File('env/${flavor.name}.example.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((k, v) => MapEntry(k, v as String));
}

/// Extracts `manifestPlaceholders["appLabel"] = "..."` per product flavor.
/// (Was `resValue`, which AGP 9 disables by default: QA BUG-1.)
Map<String, String> _gradleAppNames() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final names = <String, String>{};
  final flavorBlock = RegExp(
    r'create\("(\w+)"\)\s*\{([^}]*)\}',
    multiLine: true,
  );
  final appName = RegExp(r'manifestPlaceholders\["appLabel"\]\s*=\s*"([^"]*)"');
  for (final m in flavorBlock.allMatches(gradle)) {
    final name = appName.firstMatch(m.group(2)!)?.group(1);
    if (name != null) names[m.group(1)!] = name;
  }
  return names;
}

void main() {
  for (final flavor in Flavor.values) {
    group('env/${flavor.name}.example.json', () {
      test('exists and has exactly the keys AppConfig reads', () {
        expect(_readExample(flavor).keys.toSet(), _expectedKeys);
      });

      test('passes AppConfig validation with the matching flavor', () {
        final config = AppConfig.fromMap(_readExample(flavor));
        expect(config.flavor, flavor);
        expect(config.hasBackend, flavor != Flavor.dev);
      });

      test('APP_NAME matches the Android flavor app_name', () {
        expect(
          _gradleAppNames()[flavor.name],
          _readExample(flavor)['APP_NAME'],
        );
      });
    });
  }

  test('every Dart flavor has an Android product flavor', () {
    expect(
      _gradleAppNames().keys.toSet(),
      Flavor.values.map((f) => f.name).toSet(),
    );
  });
}
