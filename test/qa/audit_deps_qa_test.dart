// QA (sub-phase 1.7): tool/audit_deps.dart against the advisory shape that
// pub.dev really returns, plus its error handling.
//
// pub.dev's /api/packages/<name>/advisories serves GitHub advisories in OSV
// format with `"type": "ECOSYSTEM"` ranges and explicit `null` event fields
// (fetched 2026-10-29 for dio and http). The developer's tests use SEMVER
// ranges only.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug. Run them with:
//   flutter test test/qa --dart-define=QA_KNOWN_BUGS=true
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/audit_deps.dart';

LockedPackage _dio(String version) => LockedPackage(
  name: 'dio',
  version: version,
  source: 'hosted',
  url: 'https://pub.dev',
);

/// GHSA-9324-jv53-9cc8 as pub.dev serves it, with the enumerated `versions`
/// list replaced by [versions] (the real list ends at 4.0.6).
Map<String, Object?> _dioAdvisory({
  List<String> versions = const [],
  List<Map<String, Object?>>? events,
}) => {
  'advisories': [
    {
      'schema_version': '1.7.3',
      'id': 'GHSA-9324-jv53-9cc8',
      'summary': 'dio vulnerable to CRLF injection with HTTP method string',
      'affected': [
        {
          'package': {'ecosystem': 'Pub', 'name': 'dio', 'purl': 'pkg:pub/dio'},
          'ranges': [
            {
              'type': 'ECOSYSTEM',
              'repo': null,
              'events':
                  events ??
                  [
                    {
                      'introduced': '0',
                      'fixed': null,
                      'last_affected': null,
                      'limit': null,
                    },
                    {
                      'introduced': null,
                      'fixed': '5.0.0',
                      'last_affected': null,
                      'limit': null,
                    },
                  ],
              'database_specific': null,
            },
          ],
          'versions': versions,
          'database_specific': null,
          'ecosystem_specific': null,
        },
      ],
    },
  ],
  'advisoriesUpdated': '2024-02-16T08:19:11.352648Z',
};

void main() {
  group('real pub.dev advisory shape', () {
    test('QA guard: an enumerated version is reported', () {
      final json = _dioAdvisory(versions: ['4.0.5', '4.0.6']);
      expect(advisoryProblems(_dio('4.0.6'), json).single, contains('GHSA'));
    });

    // BUG-2: _affects skips every range whose type is not SEMVER
    // (tool/audit_deps.dart:148), and pub.dev only serves ECOSYSTEM ranges,
    // so detection silently depends on the enumerated `versions` list.
    test('an ECOSYSTEM range is evaluated without a versions list', () {
      final json = _dioAdvisory();
      expect(advisoryProblems(_dio('4.0.6'), json), hasLength(1));
      expect(advisoryProblems(_dio('5.0.0-dev.1'), json), hasLength(1));
      expect(advisoryProblems(_dio('5.0.0'), json), isEmpty);
    });

    test('an open ECOSYSTEM range (no fix yet) affects later versions', () {
      final json = _dioAdvisory(
        versions: ['5.9.0'],
        events: [
          {
            'introduced': '5.9.0',
            'fixed': null,
            'last_affected': null,
            'limit': null,
          },
        ],
      );
      // 5.9.1 was published after the advisory was enumerated.
      expect(advisoryProblems(_dio('5.9.1'), json), hasLength(1));
    });
  });

  group('BUG-6: failures are reported, not crashed on', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('audit_qa'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<ProcessResult> audit(String lockfile) {
      final lock = File('${dir.path}/pubspec.lock')
        ..writeAsStringSync(lockfile);
      final root = Platform.environment['FLUTTER_ROOT'];
      final dart = root == null ? 'dart' : '$root/bin/dart';
      return Process.run(dart, ['run', 'tool/audit_deps.dart', lock.path]);
    }

    test('a package without a version is an ::error::, exit 1', () async {
      final result = await audit('''
packages:
  collection:
    dependency: transitive
    description:
      name: collection
      url: "https://pub.dev"
    source: hosted
''');
      expect(result.exitCode, 1);
      expect(result.stderr as String, contains('::error::'));
    });

    test('a lockfile without packages fails', () async {
      final result = await audit('sdks:\n  dart: ">=3.13.0 <4.0.0"\n');
      expect(result.exitCode, isNot(0));
    });
  });

  // R2-3: since round 1, an event version that doesn't parse ends the range
  // as "not affected" (`_ => false`, then `introduced = null`), so a
  // malformed advisory is silently ignored instead of failing closed.
  test('R2-3: an unparseable fixed version keeps the range affected', () {
    final json = _dioAdvisory(
      events: [
        {'introduced': '0'},
        {'fixed': '5.0'},
      ],
    );
    expect(advisoryProblems(_dio('4.0.6'), json), hasLength(1));
  });

  // R3-4: an `introduced` version that doesn't parse still drops the range
  // (introduced = null), so the advisory fails open.
  test('R3-4: an unparseable introduced version keeps the range affected', () {
    final json = _dioAdvisory(
      events: [
        {'introduced': '1.0'},
        {'fixed': '5.0.0'},
      ],
    );
    expect(advisoryProblems(_dio('4.0.6'), json), hasLength(1));
  });
}
