import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

/// Build-time configuration for one environment.
///
/// Values come from `--dart-define-from-file=env/<flavor>.json`. Everything
/// here ends up inside the app binary and can be extracted by anyone, so it
/// must only ever hold **public** values (the Supabase URL and the
/// publishable/anon key). Secrets belong on the server.
@immutable
final class AppConfig {
  const new({
    required this.flavor,
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Reads and validates the values compiled into this build.
  factory fromEnvironment() => AppConfig.fromMap(const {
    'FLAVOR': String.fromEnvironment('FLAVOR'),
    'APP_NAME': String.fromEnvironment('APP_NAME'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
  });

  /// Builds a config from raw values, collecting every problem before
  /// throwing so a misconfigured build reports all issues at once.
  ///
  /// Throws an [AppConfigException] if any value is invalid.
  factory fromMap(Map<String, String> values) {
    final problems = <String>[];

    final rawFlavor = values['FLAVOR']?.trim() ?? '';
    final flavor = Flavor.tryParse(rawFlavor);
    if (flavor == null) {
      problems.add(
        rawFlavor.isEmpty
            ? 'FLAVOR is missing. Build with '
                  '--dart-define-from-file=env/<flavor>.json.'
            : 'FLAVOR "$rawFlavor" is not one of '
                  '${Flavor.values.map((f) => f.name).join(', ')}.',
      );
    }

    final appName = values['APP_NAME']?.trim() ?? '';
    if (appName.isEmpty) problems.add('APP_NAME is missing.');

    final supabaseUrl = values['SUPABASE_URL']?.trim() ?? '';
    final supabaseAnonKey = values['SUPABASE_ANON_KEY']?.trim() ?? '';
    // Dev builds may run without a backend until one is configured.
    final backendRequired = flavor != null && flavor != Flavor.dev;

    if (supabaseUrl.isEmpty) {
      if (backendRequired) problems.add('SUPABASE_URL is missing.');
    } else {
      final uri = Uri.tryParse(supabaseUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        problems.add('SUPABASE_URL must be a valid https:// URL.');
      }
    }

    if (supabaseAnonKey.isEmpty) {
      if (backendRequired) problems.add('SUPABASE_ANON_KEY is missing.');
    } else if (_looksLikeSecretKey(supabaseAnonKey)) {
      problems.add(
        'SUPABASE_ANON_KEY is a secret/service_role key. Only the '
        'publishable (anon) key may be shipped in the app.',
      );
    }

    if ((supabaseUrl.isEmpty) != (supabaseAnonKey.isEmpty)) {
      problems.add('SUPABASE_URL and SUPABASE_ANON_KEY must be set together.');
    }

    if (problems.isNotEmpty) throw AppConfigException(problems);

    return AppConfig(
      flavor: flavor!,
      appName: appName,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  final Flavor flavor;
  final String appName;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Whether a backend is configured for this build.
  bool get hasBackend => supabaseUrl.isNotEmpty;

  /// Detects Supabase secret keys: the newer `sb_secret_…` format and
  /// legacy JWT keys whose `role` claim is `service_role`.
  static bool _looksLikeSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }

  // Never print keys, even in debug logs.
  @override
  String toString() =>
      'AppConfig(flavor: ${flavor.name}, appName: $appName, '
      'hasBackend: $hasBackend)';
}

/// Thrown when the build-time configuration is invalid.
final class AppConfigException implements Exception {
  const new(this.problems);

  final List<String> problems;

  @override
  String toString() => 'Invalid app configuration:\n- ${problems.join('\n- ')}';
}
