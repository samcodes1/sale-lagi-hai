// Lints the Android security configuration (sub-phase 1.7): the manifests,
// network security config, backup rules and the release build type.
// See the flutter-secure-dev skill and docs/security/CHECKLIST.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _android = 'http://schemas.android.com/apk/res/android';
const _tools = 'http://schemas.android.com/tools';
const _main = 'android/app/src/main';

XmlDocument _xml(String path) =>
    XmlDocument.parse(File(path).readAsStringSync());

String? _attr(XmlElement e, String name, {String ns = _android}) =>
    e.getAttribute(name, namespaceUri: ns);

/// The XML resource an `@xml/name` attribute points to.
String _xmlResource(String reference) {
  if (!reference.startsWith('@xml/')) {
    throw FormatException('Not an @xml resource', reference);
  }
  return '$_main/res/xml/${reference.substring(5)}.xml';
}

void main() {
  final manifest = _xml('$_main/AndroidManifest.xml');
  final application = manifest.findAllElements('application').single;

  group('AndroidManifest', () {
    test('no cleartext traffic, and the network config is used', () {
      expect(_attr(application, 'usesCleartextTraffic'), 'false');
      expect(_attr(application, 'networkSecurityConfig'), isNotNull);
    });

    test('never debuggable or test-only', () {
      expect(_attr(application, 'debuggable'), isNull);
      expect(_attr(application, 'testOnly'), isNull);
    });

    test('backup rules are set for every Android version', () {
      // allowBackup stays on for preferences; the rules keep secure
      // storage out (checked below).
      expect(_attr(application, 'fullBackupContent'), isNotNull);
      expect(_attr(application, 'dataExtractionRules'), isNotNull);
    });

    test('only the launcher activity is exported', () {
      final components = [
        for (final tag in ['activity', 'service', 'receiver', 'provider'])
          ...application.findElements(tag),
      ];
      final exported = components
          .where((c) => _attr(c, 'exported') == 'true')
          .map((c) => _attr(c, 'name'))
          .toList();
      expect(exported, ['.MainActivity']);
      final launcher = components.singleWhere(
        (c) => _attr(c, 'name') == '.MainActivity',
      );
      final actions = launcher
          .findAllElements('action')
          .map((a) => _attr(a, 'name'))
          .toList();
      expect(actions, ['android.intent.action.MAIN']);
    });

    test('no deep links yet; Flutter deep-link handling is off', () {
      // Deep links arrive in Phase 5.3 through a validating service, as
      // verified App Links (autoVerify). Until then, no VIEW filters.
      final views = manifest
          .findAllElements('action')
          .where((a) => _attr(a, 'name') == 'android.intent.action.VIEW');
      expect(views, isEmpty);
      // FlutterActivity reads the flag from the activity's own meta-data
      // and defaults to true; under <application> it is ignored.
      final activity = application
          .findElements('activity')
          .singleWhere((a) => _attr(a, 'name') == '.MainActivity');
      final deeplinking = activity
          .findElements('meta-data')
          .singleWhere(
            (m) => _attr(m, 'name') == 'flutter_deeplinking_enabled',
          );
      expect(_attr(deeplinking, 'value'), 'false');
      expect(
        application
            .findElements('meta-data')
            .where((m) => _attr(m, 'name') == 'flutter_deeplinking_enabled'),
        isEmpty,
        reason: 'misplaced: Flutter ignores it here',
      );
    });

    test('permissions: INTERNET only; unused SDK permissions stripped', () {
      final permissions = manifest.findAllElements('uses-permission');
      final requested = permissions
          .where((p) => _attr(p, 'node', ns: _tools) != 'remove')
          .map((p) => _attr(p, 'name'))
          .toList();
      expect(requested, ['android.permission.INTERNET']);
      final removed = permissions
          .where((p) => _attr(p, 'node', ns: _tools) == 'remove')
          .map((p) => _attr(p, 'name'));
      expect(
        removed,
        containsAll([
          'android.permission.READ_PHONE_STATE',
          'com.google.android.gms.permission.AD_ID',
        ]),
      );
    });

    test('debug and profile manifests add nothing beyond INTERNET', () {
      for (final variant in ['debug', 'profile']) {
        final doc = _xml('android/app/src/$variant/AndroidManifest.xml');
        final elements = doc.rootElement.childElements.toList();
        expect(elements.map((e) => _attr(e, 'name')), [
          'android.permission.INTERNET',
        ], reason: variant);
      }
    });
  });

  group('network security config', () {
    final config = _xml(
      _xmlResource(_attr(application, 'networkSecurityConfig')!),
    );

    test('cleartext is off everywhere', () {
      final base = config.findAllElements('base-config').single;
      expect(base.getAttribute('cleartextTrafficPermitted'), 'false');
      final domainConfigs = config.findAllElements('domain-config');
      for (final d in domainConfigs) {
        expect(d.getAttribute('cleartextTrafficPermitted'), isNot('true'));
      }
    });

    test('release builds trust system CAs only', () {
      final base = config.findAllElements('base-config').single;
      final sources = base
          .findAllElements('certificates')
          .map((c) => c.getAttribute('src'))
          .toList();
      expect(sources, ['system']);
      // User CAs (for a local debugging proxy) only in debug-overrides.
      for (final c in config.findAllElements('certificates')) {
        if (c.getAttribute('src') == 'user') {
          expect(
            c.ancestorElements.map((e) => e.name.local),
            contains('debug-overrides'),
          );
        }
      }
    });
  });

  group('backup rules', () {
    const secureFiles = [
      'FlutterSecureStorage.xml',
      'FlutterSecureKeyStorage.xml',
    ];

    void expectSecureStorageExcluded(XmlElement section, String where) {
      final excluded = section
          .findElements('exclude')
          .where((e) => e.getAttribute('domain') == 'sharedpref')
          .map((e) => e.getAttribute('path'));
      expect(excluded, containsAll(secureFiles), reason: where);
    }

    test('Android 12+: cloud backup and device transfer', () {
      final rules = _xml(
        _xmlResource(_attr(application, 'dataExtractionRules')!),
      );
      final cloud = rules.findAllElements('cloud-backup').single;
      expect(cloud.getAttribute('disableIfNoEncryptionCapabilities'), 'true');
      expectSecureStorageExcluded(cloud, 'cloud-backup');
      expectSecureStorageExcluded(
        rules.findAllElements('device-transfer').single,
        'device-transfer',
      );
    });

    test('Android 11 and lower: full backup', () {
      final rules = _xml(
        _xmlResource(_attr(application, 'fullBackupContent')!),
      );
      expectSecureStorageExcluded(rules.rootElement, 'full-backup-content');
    });

    test('nothing outside preferences and DataStore is backed up', () {
      for (final path in [
        _xmlResource(_attr(application, 'dataExtractionRules')!),
        _xmlResource(_attr(application, 'fullBackupContent')!),
      ]) {
        for (final include in _xml(path).findAllElements('include')) {
          final domain = include.getAttribute('domain');
          final where = '$domain:${include.getAttribute('path')}';
          expect(where, anyOf('sharedpref:.', 'file:datastore/'), reason: path);
        }
      }
    });
  });

  group('release build', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final release = RegExp(
      r'buildTypes\s*\{\s*release\s*\{([\s\S]*?)\n        \}',
    ).firstMatch(gradle)?.group(1);

    test('R8 shrinks and obfuscates release builds', () {
      expect(release, isNotNull, reason: 'release build type not found');
      expect(release, contains('isMinifyEnabled = true'));
      expect(release, contains('isShrinkResources = true'));
      expect(release, contains('proguard-rules.pro'));
      expect(release, isNot(contains('isDebuggable = true')));
    });

    test('CI cannot ship a debug-signed release', () {
      expect(release, contains('REQUIRE_RELEASE_SIGNING'));
      expect(gradle, contains('key.properties'));
    });

    test("targets Play's required API level (36)", () {
      expect(gradle, contains('targetSdk = flutter.targetSdkVersion'));
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot == null) return;
      final extension = File(
        '$flutterRoot/packages/flutter_tools/gradle/src/main/kotlin/'
        'FlutterExtension.kt',
      );
      if (!extension.existsSync()) return;
      final target = RegExp(r'val targetSdkVersion: Int = (\d+)')
          .firstMatch(extension.readAsStringSync());
      expect(int.parse(target!.group(1)!), greaterThanOrEqualTo(36));
    });

    test('signing secrets are gitignored', () {
      final ignore = File('.gitignore').readAsStringSync();
      for (final pattern in ['key.properties', '*.jks']) {
        expect(ignore, contains(pattern));
      }
      expect(File('android/key.properties').existsSync(), isFalse);
    });
  });
}
