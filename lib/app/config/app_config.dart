import 'dart:convert';

import 'package:meta/meta.dart';
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
    required this.supabasePublishableKey,
    this.googleServerClientId = '',
    this.supportEmail = '',
  });

  /// Reads and validates the values compiled into this build.
  factory fromEnvironment() => AppConfig.fromMap(const {
    'FLAVOR': String.fromEnvironment('FLAVOR'),
    'APP_NAME': String.fromEnvironment('APP_NAME'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    'GOOGLE_SERVER_CLIENT_ID': String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    ),
    'SUPPORT_EMAIL': String.fromEnvironment('SUPPORT_EMAIL'),
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
    final supabasePublishableKey =
        values['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
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

    if (supabasePublishableKey.isEmpty) {
      if (backendRequired) problems.add('SUPABASE_PUBLISHABLE_KEY is missing.');
    } else if (!_isPublishableKey(supabasePublishableKey)) {
      problems.add(
        'SUPABASE_PUBLISHABLE_KEY must be the publishable key '
        '(sb_publishable_…) or a legacy anon JWT. Never ship a '
        'secret/service_role key.',
      );
    }

    if ((supabaseUrl.isEmpty) != (supabasePublishableKey.isEmpty)) {
      problems.add(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be set together.',
      );
    }

    // Optional: Google sign-in is offered only when it is set. A public
    // OAuth client ID (never a client secret).
    final googleServerClientId =
        values['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';
    if (googleServerClientId.isNotEmpty &&
        !_googleClientId.hasMatch(googleServerClientId)) {
      problems.add(
        'GOOGLE_SERVER_CLIENT_ID must be a Google OAuth client ID '
        '(<number>-<id>.apps.googleusercontent.com).',
      );
    }

    // Optional: where "Contact us" (Settings, About) writes to.
    final supportEmail = values['SUPPORT_EMAIL']?.trim() ?? '';
    if (supportEmail.isNotEmpty && !_email.hasMatch(supportEmail)) {
      problems.add('SUPPORT_EMAIL must be an email address.');
    }

    if (problems.isNotEmpty) throw AppConfigException(problems);

    return AppConfig(
      flavor: flavor!,
      appName: appName,
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
      googleServerClientId: googleServerClientId,
      supportEmail: supportEmail,
    );
  }

  // The same rule as LinkService.email: one plain address.
  static final _email = RegExp(r'^[^@\s?&#/:,;%]+@[^@\s?&#/:,;%]+\.[a-z]{2,}$');

  static final _googleClientId = RegExp(
    r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$',
  );

  final Flavor flavor;
  final String appName;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// The web OAuth client ID that Google sign-in issues ID tokens for
  /// (Supabase verifies them). Empty: Google sign-in is hidden.
  final String googleServerClientId;

  bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;

  /// The support address for "Contact us". Empty: the row is hidden.
  final String supportEmail;

  /// Whether a backend is configured for this build.
  bool get hasBackend => supabaseUrl.isNotEmpty;

  /// Throws if the native build flavor (Android/iOS `--flavor`) does not
  /// match the Dart config, e.g. a prod app ID built with `env/dev.json`.
  ///
  /// [buildFlavor] is Flutter's `appFlavor`; it is `null` on platforms
  /// without flavors (web, tests), where there is nothing to compare.
  void verifyBuildFlavor(String? buildFlavor) {
    if (buildFlavor == null || buildFlavor == flavor.name) return;
    final problem =
        'Built with --flavor $buildFlavor but the config is for '
        '${flavor.name}. Use --dart-define-from-file=env/$buildFlavor.json.';
    throw AppConfigException([problem]);
  }

  /// An allowlist: only the publishable key format, or a legacy JWT key
  /// whose `role` claim is exactly `anon`, may ship in the app. Anything
  /// else (secret keys, service_role or admin JWTs, unrelated tokens) is
  /// rejected.
  static bool _isPublishableKey(String key) {
    const prefix = 'sb_publishable_';
    if (key.startsWith(prefix)) return key.length > prefix.length;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'anon';
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
