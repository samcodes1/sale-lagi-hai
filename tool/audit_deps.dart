import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// Audits the resolved dependencies in pubspec.lock.
///
/// Offline (always):
/// - every package comes from pub.dev or the Flutter SDK: no git, path or
///   third-party hosted sources, which skip pub.dev's checks;
/// - none is on the project's banned list (discontinued or replaced).
///
/// Online (`--online`, used in CI) for every package, from pub.dev's API:
/// - the locked version is not affected by a published security advisory;
/// - the locked version is not retracted;
/// - the package is not discontinued.
///
/// OSV-Scanner also runs in CI; this adds the pub-specific checks it
/// doesn't do and works without a GitHub token.
///
/// Usage: dart run tool/audit_deps.dart [pubspec.lock] [--online]
Future<void> main(List<String> args) async {
  final path = args.firstWhere(
    (a) => !a.startsWith('--'),
    orElse: () => 'pubspec.lock',
  );
  final packages = parseLockfile(File(path).readAsStringSync());
  final problems = [
    if (packages.isEmpty) '$path lists no packages; is it a pubspec.lock?',
    for (final p in packages) ...offlineProblems(p),
    // Fails closed: a package that can't be checked is a problem too.
    if (args.contains('--online')) ...await _onlineProblems(packages),
  ];

  if (problems.isEmpty) {
    stdout.writeln('Dependency audit passed: ${packages.length} packages.');
    return;
  }
  for (final problem in problems) {
    stderr.writeln('::error::$problem');
  }
  exit(1);
}

/// Packages the project must not use (CLAUDE.md, docs/research/packages.md).
const bannedPackages = <String, String>{
  'golden_toolkit': 'discontinued; use alchemist',
  'uni_links': 'discontinued; use app_links',
  'firebase_dynamic_links': 'service shut down; use App Links',
  'intl_utils': 'discontinued; use gen-l10n',
  'hive': 'unmaintained; use shared_preferences / sqlite',
  'isar': 'unmaintained; use shared_preferences / sqlite',
  'flutter_markdown': 'discontinued; use flutter_markdown_plus',
};

/// One resolved package from pubspec.lock.
final class LockedPackage {
  const new({
    required this.name,
    required this.version,
    required this.source,
    this.url,
  });

  final String name;
  final String version;

  /// `hosted`, `sdk`, `git` or `path`.
  final String source;

  /// The pub server, for hosted packages.
  final String? url;
}

List<LockedPackage> parseLockfile(String lockfile) {
  final Object? yaml;
  try {
    yaml = loadYaml(lockfile);
  } on YamlException {
    return const []; // not YAML: reported as "lists no packages"
  }
  if (yaml is! YamlMap) return const []; // empty or not a lockfile
  final packages = switch (yaml['packages']) {
    final YamlMap map => map,
    _ => YamlMap(),
  };
  return [
    for (final MapEntry(:key, :value) in packages.entries)
      if (value case final YamlMap entry)
        LockedPackage(
          name: key as String,
          // Missing fields become offline problems, not crashes.
          version: entry['version'] is String ? entry['version'] as String : '',
          source: entry['source'] is String ? entry['source'] as String : '',
          url: switch (entry['description']) {
            final YamlMap d => d['url'] as String?,
            _ => null,
          },
        ),
  ];
}

List<String> offlineProblems(LockedPackage p) => [
  if (p.source != 'sdk' && _parseVersion(p.version) == null)
    '${p.name} has no valid version in the lockfile.',
  if (bannedPackages[p.name] case final reason?)
    '${p.name} is banned: $reason.',
  switch (p.source) {
    'sdk' => null,
    'hosted' when p.url == 'https://pub.dev' => null,
    'hosted' => '${p.name} comes from ${p.url}, not pub.dev.',
    _ => '${p.name} is a ${p.source} dependency; publish it or vendor it.',
  },
].whereType<String>().toList();

/// Problems in pub.dev's package metadata (`/api/packages/<name>`).
List<String> metadataProblems(LockedPackage p, Map<String, Object?> json) {
  final versions = (json['versions'] as List<Object?>? ?? [])
      .cast<Map<String, Object?>>();
  final locked = versions.where((v) => v['version'] == p.version);
  final replacement = switch (json['replacedBy']) {
    final String name => '; use $name',
    _ => '',
  };
  return [
    if (json['isDiscontinued'] == true)
      '${p.name} is discontinued$replacement.',
    if (locked.any((v) => v['retracted'] == true))
      '${p.name} ${p.version} is retracted; run flutter pub upgrade.',
  ];
}

/// Advisories (`/api/packages/<name>/advisories`, OSV format) that affect
/// the locked version.
List<String> advisoryProblems(LockedPackage p, Map<String, Object?> json) {
  final version = _parseVersion(p.version);
  if (version == null) return const [];
  final problems = <String>[];
  for (final advisory
      in (json['advisories'] as List<Object?>? ?? [])
          .cast<Map<String, Object?>>()) {
    if (advisory['withdrawn'] != null) continue;
    final affected = (advisory['affected'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .where((a) => (a['package'] as Map?)?['name'] == p.name);
    if (affected.any((a) => _affects(a, version))) {
      problems.add(
        '${p.name} ${p.version} is affected by ${advisory['id']}: '
        '${advisory['summary'] ?? 'security advisory'}.',
      );
    }
  }
  return problems;
}

bool _affects(Map<String, Object?> affected, Version version) {
  final listed = (affected['versions'] as List<Object?>? ?? []).cast<String>();
  if (listed.contains(version.toString())) return true;
  for (final range
      in (affected['ranges'] as List<Object?>? ?? [])
          .cast<Map<String, Object?>>()) {
    // pub.dev serves ECOSYSTEM ranges; pub versions are semver, so both
    // compare the same way. GIT ranges (commit hashes) don't apply.
    if (range['type'] != 'SEMVER' && range['type'] != 'ECOSYSTEM') continue;
    // OSV events, in order: introduced, then fixed or last_affected.
    Version? introduced;
    for (final event
        in (range['events'] as List<Object?>? ?? [])
            .cast<Map<String, Object?>>()) {
      if (event['introduced'] case final String v) {
        // An unparseable start fails closed: affected from the beginning.
        introduced = v == '0'
            ? Version.none
            : (_parseVersion(v) ?? Version.none);
      } else if (introduced != null) {
        final inRange = switch (event) {
          // An end we can't parse fails closed: still affected.
          {'fixed': final String v} =>
            version >= introduced &&
                (_parseVersion(v) == null || version < _parseVersion(v)!),
          {'last_affected': final String v} =>
            version >= introduced &&
                (_parseVersion(v) == null || version <= _parseVersion(v)!),
          _ => false,
        };
        if (inRange) return true;
        introduced = null;
      }
    }
    if (introduced != null && version >= introduced) return true;
  }
  return false;
}

Future<List<String>> _onlineProblems(List<LockedPackage> packages) async {
  final client = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'sale-lagi-hai-audit (+tool/audit_deps.dart)';
  try {
    final problems = <String>[];
    var networkFailures = 0;
    for (final p in packages.where((p) => p.source == 'hosted')) {
      // pub.dev is unreachable: say so once instead of timing out on every
      // package (the run still fails).
      if (networkFailures >= 3) {
        problems.add('pub.dev is unreachable; the online checks did not run.');
        break;
      }
      final base =
          'https://pub.dev/api/packages/${Uri.encodeComponent(p.name)}';
      try {
        problems
          ..addAll(metadataProblems(p, await _getJson(client, base)))
          ..addAll(
            advisoryProblems(p, await _getJson(client, '$base/advisories')),
          );
        networkFailures = 0;
      } on _NotFound {
        problems.add('${p.name} is not on pub.dev (removed or unpublished).');
      } on _Rejected catch (e) {
        problems.add('${p.name} could not be checked: ${e.message}');
      } on Exception catch (e) {
        networkFailures++;
        problems.add('${p.name} could not be checked: $e');
      }
    }
    return problems;
  } finally {
    client.close(force: true);
  }
}

final class _NotFound implements Exception;

/// A response that retrying won't fix (4xx other than 404 and 429).
final class _Rejected implements Exception {
  const new(this.message);
  final String message;
}

/// GETs JSON. The whole request (including the body) has a 30 s timeout;
/// network errors, timeouts, 429 and 5xx are retried twice with backoff.
Future<Map<String, Object?>> _getJson(HttpClient client, String url) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final (status, body) = await () async {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('accept', 'application/json');
        final response = await request.close();
        return (
          response.statusCode,
          await response.transform(utf8.decoder).join(),
        );
      }().timeout(const Duration(seconds: 30));
      if (status == 200) return jsonDecode(body) as Map<String, Object?>;
      if (status == 404) throw _NotFound();
      if (status != 429 && status < 500) {
        throw _Rejected('$url answered $status');
      }
      if (attempt >= 3) throw HttpException('$url answered $status');
    } on _NotFound {
      rethrow;
    } on _Rejected {
      rethrow;
    } on Exception {
      // SocketException, TimeoutException, HttpException (429, 5xx)...
      if (attempt >= 3) rethrow;
    }
    await Future<void>.delayed(Duration(seconds: 2 * attempt));
  }
}

Version? _parseVersion(String text) {
  try {
    return Version.parse(text);
  } on FormatException {
    return null;
  }
}
