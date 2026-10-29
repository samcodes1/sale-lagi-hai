import 'package:flutter_test/flutter_test.dart';

// The tool lives outside lib/, so import it by path.
import '../../tool/audit_deps.dart';

const _lock = '''
packages:
  collection:
    dependency: transitive
    description:
      name: collection
      sha256: "abc"
      url: "https://pub.dev"
    source: hosted
    version: "1.19.1"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  forked:
    dependency: "direct main"
    description:
      path: "."
      ref: main
      resolved-ref: "deadbeef"
      url: "https://github.com/someone/forked.git"
    source: git
    version: "1.0.0"
  mirror:
    dependency: transitive
    description:
      name: mirror
      sha256: "abc"
      url: "https://pub.example.com"
    source: hosted
    version: "2.0.0"
  hive:
    dependency: "direct main"
    description:
      name: hive
      sha256: "abc"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.3"
sdks:
  dart: ">=3.13.0 <4.0.0"
''';

LockedPackage _pkg(String version, {String name = 'pkg'}) => LockedPackage(
  name: name,
  version: version,
  source: 'hosted',
  url: 'https://pub.dev',
);

Map<String, Object?> _advisory(
  List<Map<String, Object?>> ranges, {
  List<String> versions = const [],
  String? withdrawn,
}) => {
  'advisories': [
    {
      'id': 'GHSA-test',
      'summary': 'Bad thing',
      'withdrawn': ?withdrawn,
      'affected': [
        {
          'package': {'name': 'pkg', 'ecosystem': 'Pub'},
          'ranges': ranges,
          'versions': versions,
        },
      ],
    },
  ],
};

void main() {
  group('lockfile', () {
    final packages = {for (final p in parseLockfile(_lock)) p.name: p};

    test('parses every package', () {
      expect(packages.keys, [
        'collection',
        'flutter',
        'forked',
        'mirror',
        'hive',
      ]);
      expect(packages['collection']!.url, 'https://pub.dev');
      expect(packages['flutter']!.source, 'sdk');
    });

    test('pub.dev and SDK packages pass', () {
      expect(offlineProblems(packages['collection']!), isEmpty);
      expect(offlineProblems(packages['flutter']!), isEmpty);
    });

    test('git, path and other servers fail', () {
      expect(offlineProblems(packages['forked']!).single, contains('git'));
      expect(
        offlineProblems(packages['mirror']!).single,
        contains('pub.example.com'),
      );
    });

    test('banned packages fail', () {
      expect(offlineProblems(packages['hive']!).single, contains('banned'));
    });
  });

  group('advisories', () {
    test('a version inside introduced..fixed is affected', () {
      final json = _advisory([
        {
          'type': 'SEMVER',
          'events': [
            {'introduced': '0'},
            {'fixed': '1.4.0'},
          ],
        },
      ]);
      expect(advisoryProblems(_pkg('1.3.9'), json).single, contains('GHSA'));
      expect(advisoryProblems(_pkg('1.4.0'), json), isEmpty);
    });

    test('last_affected is inclusive; open ranges stay affected', () {
      final json = _advisory([
        {
          'type': 'SEMVER',
          'events': [
            {'introduced': '2.0.0'},
            {'last_affected': '2.1.0'},
            {'introduced': '3.0.0'},
          ],
        },
      ]);
      expect(advisoryProblems(_pkg('1.9.0'), json), isEmpty);
      expect(advisoryProblems(_pkg('2.1.0'), json), hasLength(1));
      expect(advisoryProblems(_pkg('2.2.0'), json), isEmpty);
      expect(advisoryProblems(_pkg('3.5.0'), json), hasLength(1));
    });

    test('explicitly listed versions are affected', () {
      final json = _advisory([], versions: ['1.0.1']);
      expect(advisoryProblems(_pkg('1.0.1'), json), hasLength(1));
      expect(advisoryProblems(_pkg('1.0.2'), json), isEmpty);
    });

    test('withdrawn advisories and other packages are ignored', () {
      final ranges = [
        {
          'type': 'SEMVER',
          'events': [
            {'introduced': '0'},
          ],
        },
      ];
      expect(
        advisoryProblems(_pkg('1.0.0'), _advisory(ranges, withdrawn: '2026')),
        isEmpty,
      );
      expect(
        advisoryProblems(_pkg('1.0.0', name: 'other'), _advisory(ranges)),
        isEmpty,
      );
    });

    test('no advisories, no problems', () {
      expect(
        advisoryProblems(_pkg('1.0.0'), {'advisories': <Object>[]}),
        isEmpty,
      );
    });
  });

  group('package metadata', () {
    test('discontinued packages fail, naming the replacement', () {
      expect(
        metadataProblems(_pkg('1.0.0'), {
          'isDiscontinued': true,
          'replacedBy': 'better_pkg',
          'versions': <Object>[],
        }).single,
        contains('use better_pkg'),
      );
    });

    test('a retracted locked version fails', () {
      final json = {
        'versions': [
          {'version': '1.0.0', 'retracted': true},
          {'version': '1.0.1'},
        ],
      };
      expect(
        metadataProblems(_pkg('1.0.0'), json).single,
        contains('retracted'),
      );
      expect(metadataProblems(_pkg('1.0.1'), json), isEmpty);
    });
  });
}
