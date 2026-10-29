import 'dart:convert';

import 'package:sale_lagi_hai/app/config/app_config.dart';

/// The keys an `env/<flavor>.json` file may contain.
const envFileKeys = {
  'FLAVOR',
  'APP_NAME',
  'SUPABASE_URL',
  'SUPABASE_PUBLISHABLE_KEY',
};

/// Template values from `env/*.example.json` that must be replaced before a
/// real release. Matched case-insensitively (markers are upper case).
const _placeholderMarkers = ['REPLACE_ME', 'YOUR-'];

/// Validates the contents of an env file **before** a build, so a bad config
/// (above all a secret key) never gets compiled into a binary.
///
/// Returns every problem found; an empty list means the file is valid.
/// Used by `tool/check_env.dart` in CI. Pure Dart, no Flutter imports.
List<String> validateEnvFile(
  String contents, {
  String? expectedFlavor,
  bool allowPlaceholders = false,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(contents);
  } on FormatException catch (e) {
    return ['Not valid JSON: ${e.message}'];
  }
  if (decoded is! Map<String, Object?>) {
    return ['The file must contain a JSON object.'];
  }

  final problems = <String>[];
  final values = <String, String>{};
  for (final MapEntry(:key, :value) in decoded.entries) {
    if (!envFileKeys.contains(key)) {
      problems.add('Unknown key "$key" (allowed: ${envFileKeys.join(', ')}).');
    } else if (value is! String) {
      problems.add('"$key" must be a string.');
    } else {
      values[key] = value;
      if (!allowPlaceholders &&
          _placeholderMarkers.any(value.toUpperCase().contains)) {
        problems.add('"$key" still has a template placeholder value.');
      }
    }
  }

  try {
    AppConfig.fromMap(values).verifyBuildFlavor(expectedFlavor);
  } on AppConfigException catch (e) {
    problems.addAll(e.problems);
  }
  return problems;
}
