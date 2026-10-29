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
    for (final p in packages) ...offlineProblems(p),
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
  final yaml = loadYaml(lockfile) as YamlMap;
  final packages = (yaml['packages'] as YamlMap?) ?? YamlMap();
  return [
    for (final MapEntry(:key, :value) in packages.entries)
      if (value case final YamlMap entry)
        LockedPackage(
          name: key as String,
          version: entry['version'] as String,
          source: entry['source'] as String,
          url: switch (entry['description']) {
            final YamlMap d => d['url'] as String?,
            _ => null,
          },
        ),
  ];
}

List<String> offlineProblems(LockedPackage p) => [
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
  final version = Version.parse(p.version);
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
    if (range['type'] != 'SEMVER') continue;
    // OSV events, in order: introduced, then fixed or last_affected.
    Version? introduced;
    for (final event
        in (range['events'] as List<Object?>? ?? [])
            .cast<Map<String, Object?>>()) {
      if (event['introduced'] case final String v) {
        introduced = v == '0' ? Version.none : Version.parse(v);
      } else if (introduced != null) {
        final inRange = switch (event) {
          {'fixed': final String v} =>
            version >= introduced && version < Version.parse(v),
          {'last_affected': final String v} =>
            version >= introduced && version <= Version.parse(v),
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
    ..userAgent = 'sale-lagi-hai-audit (+tool/audit_deps.dart)';
  try {
    final problems = <String>[];
    for (final p in packages.where((p) => p.source == 'hosted')) {
      final base = 'https://pub.dev/api/packages/${p.name}';
      problems
        ..addAll(metadataProblems(p, await _getJson(client, base)))
        ..addAll(
          advisoryProblems(p, await _getJson(client, '$base/advisories')),
        );
    }
    return problems;
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _getJson(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set('accept', 'application/json');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw HttpException('$url answered ${response.statusCode}');
  }
  return jsonDecode(body) as Map<String, Object?>;
}
