// QA (sub-phase 1.7, security baseline): reproducers for gaps in the
// Android manifest lint, the source-hygiene test and the gitleaks rules,
// plus guards for blind spots of test/security/android_config_test.dart.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug. Run them with:
//   flutter test test/qa --dart-define=QA_KNOWN_BUGS=true
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _android = 'http://schemas.android.com/apk/res/android';
const _tools = 'http://schemas.android.com/tools';

String? _attr(XmlElement e, String name, {String ns = _android}) =>
    e.getAttribute(name, namespaceUri: ns);

XmlDocument _xml(String path) =>
    XmlDocument.parse(File(path).readAsStringSync());

const _components = [
  'activity',
  'activity-alias',
  'service',
  'receiver',
  'provider',
];

/// Every manifest Gradle merges into the app from this module: main, build
/// types (debug, profile, release), flavors and flavor+type source sets.
List<File> _sourceSetManifests() => [
  for (final dir in Directory('android/app/src').listSync())
    if (dir is Directory &&
        File('${dir.path}/AndroidManifest.xml').existsSync())
      File('${dir.path}/AndroidManifest.xml'),
];

/// The root directory of a resolved package, from package_config.json.
Directory _packageRoot(String name) {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final packages = (config['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final entry = packages.singleWhere((p) => p['name'] == name);
  final root = Uri.parse(entry['rootUri']! as String);
  return Directory.fromUri(
    root.isAbsolute ? root : Uri.directory('.dart_tool/').resolveUri(root),
  );
}

/// The joined string literals of the first `RegExp(...)` after [anchor] in
/// the hygiene test, so these reproducers always run the developer's
/// current patterns.
({RegExp regExp, String source}) _hygienePattern(String anchor) {
  final source = File('test/security/source_hygiene_test.dart')
      .readAsStringSync();
  final start = source.indexOf(anchor);
  if (start < 0) {
    fail(
      'QA: "$anchor" is gone from source_hygiene_test.dart; '
      'update this reproducer.',
    );
  }
  var i = source.indexOf('RegExp(', start) + 'RegExp('.length;
  final argStart = i;
  var depth = 1;
  final literals = StringBuffer();
  while (depth > 0) {
    final c = source[i];
    if (c == '/' && source[i + 1] == '/') {
      i = source.indexOf('\n', i);
      continue;
    }
    final raw = c == 'r' && source[i + 1] == "'";
    if (raw || c == "'") {
      i += raw ? 2 : 1;
      while (source[i] != "'") {
        if (!raw && source[i] == r'\') {
          literals.write(source[i + 1]);
          i += 2;
        } else {
          literals.write(source[i]);
          i++;
        }
      }
      i++;
      continue;
    }
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  final args = source.substring(argStart, i);
  return (
    regExp: RegExp(
      literals.toString(),
      multiLine: args.contains('multiLine: true'),
    ),
    source: literals.toString(),
  );
}

/// Applies the hygiene test's comment stripping, then the check pattern of
/// the test that starts with [checkAnchor].
bool _hygieneCatches(String code, String checkAnchor) {
  final strip = _hygienePattern('String _code(').regExp;
  final check = _hygienePattern(checkAnchor).regExp;
  return check.hasMatch(code.replaceAll(strip, ''));
}

/// A gitleaks rule's regex from .gitleaks.toml, with Go's leading inline
/// flags turned into Dart flags (Dart has no inline flag groups).
RegExp _gitleaksRule(String id) {
  final toml = File('.gitleaks.toml').readAsStringSync();
  final block = toml
      .split('[[rules]]')
      .firstWhere((b) => b.contains('id = "$id"'));
  final go = RegExp(
    "regex = '''(.*?)'''",
    dotAll: true,
  ).firstMatch(block)!.group(1)!;
  final flags = RegExp(r'^\(\?([a-z]+)\)').firstMatch(go)?.group(1) ?? '';
  return RegExp(
    go.substring(flags.isEmpty ? 0 : flags.length + 3),
    caseSensitive: !flags.contains('i'),
    multiLine: flags.contains('m'),
  );
}

void main() {
  group('BUG-1: Flutter deep-link handling is still on', () {
    // FlutterActivity reads `flutter_deeplinking_enabled` from the
    // ACTIVITY's meta-data (getActivityInfo(getComponentName(),
    // GET_META_DATA).metaData) and defaults to true when it is missing:
    // engine/src/flutter/shell/platform/android/io/flutter/embedding/
    // android/FlutterActivity.java:1313 and FlutterActivityLaunchConfigs
    // .java:55. The flag sits under <application>, so it is ignored, and any
    // app can start the exported MainActivity with setData(<route>) to drive
    // the router, bypassing the planned validating DeepLinkService.
    test('the flag is meta-data of MainActivity', () {
      final activity = _xml('android/app/src/main/AndroidManifest.xml')
          .findAllElements('activity')
          .singleWhere((a) => _attr(a, 'name') == '.MainActivity');
      final flag = activity
          .findElements('meta-data')
          .where((m) => _attr(m, 'name') == 'flutter_deeplinking_enabled');
      expect(flag, hasLength(1), reason: 'not declared on the activity');
      expect(_attr(flag.single, 'value'), 'false');
    });
  });

  group('QA guard: manifests the lint does not read', () {
    test('every source-set manifest is known and hardened', () {
      final manifests = _sourceSetManifests();
      expect(
        manifests.map((f) => f.parent.uri.pathSegments.reversed.elementAt(1)),
        unorderedEquals(['main', 'debug', 'profile']),
        reason:
            'a new source-set manifest (flavor or release) is merged '
            'into the app; add it to android_config_test.dart',
      );
      for (final file in manifests) {
        final doc = _xml(file.path);
        for (final app in doc.findAllElements('application')) {
          expect(_attr(app, 'usesCleartextTraffic'), isNot('true'));
          expect(_attr(app, 'debuggable'), isNull, reason: file.path);
          expect(_attr(app, 'allowBackup'), isNot('false'), reason: file.path);
        }
      }
    });

    test('activity-alias and every component declare exported; only '
        'MainActivity is exported', () {
      final application = _xml('android/app/src/main/AndroidManifest.xml')
          .findAllElements('application')
          .single;
      final components = [
        for (final tag in _components) ...application.findAllElements(tag),
      ];
      for (final c in components) {
        expect(_attr(c, 'exported'), isNotNull, reason: _attr(c, 'name'));
      }
      expect(
        components
            .where((c) => _attr(c, 'exported') == 'true')
            .map((c) => _attr(c, 'name')),
        ['.MainActivity'],
      );
    });

    test('no permission through uses-permission-sdk-23 or <permission>', () {
      for (final file in _sourceSetManifests()) {
        final doc = _xml(file.path);
        final sdk23 = doc
            .findAllElements('uses-permission-sdk-23')
            .where((p) => _attr(p, 'node', ns: _tools) != 'remove');
        expect(sdk23, isEmpty, reason: file.path);
        expect(doc.findAllElements('permission'), isEmpty, reason: file.path);
      }
    });
  });

  group('QA guard: backup rules match where the plugins store data', () {
    test('secure storage file names are the plugin defaults', () {
      // flutter_secure_storage v11: data in <getEffectiveDataPrefsName>.xml,
      // the wrapped AES key in FlutterSecureKeyStorage.xml (no namespace).
      final config = File(
        '${_packageRoot('flutter_secure_storage').path}/android/src/main/'
        'java/com/it_nomads/fluttersecurestorage/'
        'FlutterSecureStorageConfig.java',
      ).readAsStringSync();
      final dataName = RegExp(r'DEFAULT_PREF_NAME = "(\w+)"')
          .firstMatch(config)!
          .group(1);
      expect(config, contains(': "FlutterSecureKeyStorage"'));
      // The app must not set storageNamespace, which renames both files.
      expect(
        File('lib/core/storage/secure_store.dart').readAsStringSync(),
        isNot(contains('storageNamespace')),
      );
      for (final path in [
        'android/app/src/main/res/xml/data_extraction_rules.xml',
        'android/app/src/main/res/xml/backup_rules.xml',
      ]) {
        final excluded = _xml(path)
            .findAllElements('exclude')
            .where((e) => e.getAttribute('domain') == 'sharedpref')
            .map((e) => e.getAttribute('path'));
        expect(
          excluded,
          containsAll(['$dataName.xml', 'FlutterSecureKeyStorage.xml']),
          reason: path,
        );
      }
    });

    test("SharedPreferencesAsync's DataStore file is under datastore/", () {
      final plugin = File(
        '${_packageRoot('shared_preferences_android').path}/android/src/'
        'main/kotlin/io/flutter/plugins/sharedpreferences/'
        'SharedPreferencesPlugin.kt',
      ).readAsStringSync();
      // preferencesDataStore(name) writes files/datastore/<name>.preferences_pb
      expect(plugin, contains('preferencesDataStore(SHARED_PREFERENCES_NAME)'));
      expect(
        File('lib/core/storage/key_value_store.dart').readAsStringSync(),
        contains('SharedPreferencesAsync'),
      );
    });
  });

  group('BUG-3: source hygiene misses common cleartext and console forms', () {
    const cleartext = "test('no cleartext URLs'";
    const console = "test('no print or debugPrint";
    final cases = <(String, String, String)>[
      ('Uri.http constructor', cleartext, "final u = Uri.http('api.x.pk');"),
      (
        'Uri with an http scheme',
        cleartext,
        "final u = Uri(scheme: 'http', host: 'api.x.pk');",
      ),
      ('upper-case scheme', cleartext, "const u = 'HTTP://api.x.pk/deals';"),
      ('adjacent literals', cleartext, "const u = 'http:' '//api.x.pk';"),
      (
        'allowlisted host as a prefix',
        cleartext,
        "const u = 'http://localhost.attacker.example/x';",
      ),
      ('cleartext WebSocket', cleartext, "const u = 'ws://api.x.pk/socket';"),
      (
        'comment stripping eats the rest of a line',
        cleartext,
        "final a = [' //', 'http://api.x.pk'];",
      ),
      ('debugPrintSynchronously', console, 'debugPrintSynchronously(token);'),
      ('debugPrintThrottled', console, 'debugPrintThrottled(token);'),
      ('dart:developer log', console, 'developer.log(token);'),
      (
        'print after a string holding //',
        console,
        "final a = ' //'; print(token);",
      ),
    ];
    for (final (name, anchor, code) in cases) {
      test(name, () {
        expect(_hygieneCatches(code, anchor), isTrue, reason: code);
      });
    }

    test('positive control: the extracted patterns still catch the basics', () {
      expect(_hygieneCatches("const u = 'http://api.x.pk';", cleartext), true);
      expect(_hygieneCatches("print('x');", console), true);
      expect(_hygieneCatches("// print('x');", console), false);
      expect(
        _hygienePattern("test('no secret keys").regExp
            .hasMatch('sb_secret_abcdefghijkl'),
        isTrue,
      );
    });
  });

  group('gitleaks rules (.gitleaks.toml)', () {
    const ids = [
      'supabase-secret-key',
      'supabase-service-role-key',
      'supabase-db-connection-string',
      'android-signing-password',
    ];

    test('custom rules are RE2-safe (no lookaround, backreference, atomic '
        'or possessive)', () {
      final toml = File('.gitleaks.toml').readAsStringSync();
      final regexes = RegExp(
        "'''(.*?)'''",
        dotAll: true,
      ).allMatches(toml).map((m) => m.group(1)!).toList();
      expect(regexes.length, greaterThanOrEqualTo(ids.length));
      for (final r in regexes) {
        expect(r, isNot(matches(r'\(\?[=!<>]|\\[1-9]|[*+?}]\+')), reason: r);
      }
    });

    // Fixtures are split across literals so the committed file does not
    // trip gitleaks itself (a contiguous value would fail CI's secret scan).
    test('positive controls', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJyb2xlIjoic2VydmljZV9yb2xlIn0.'
          'dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(
        _gitleaksRule(ids[0]).hasMatch(
          'KEY=sb_secret_'
          'N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz',
        ),
        isTrue,
      );
      expect(
        _gitleaksRule(ids[1]).hasMatch('SUPABASE_SERVICE_ROLE_KEY=$jwt'),
        isTrue,
      );
      expect(
        _gitleaksRule(ids[2]).hasMatch(
          'postgresql://postgres.ref:'
          'S3cretPassw0rd@aws-0.pooler.supabase.com',
        ),
        isTrue,
      );
      expect(
        _gitleaksRule(ids[3]).hasMatch('storePassword=hunter2hunter2'),
        isTrue,
      );
      // The CI-side placeholder must not be reported.
      expect(
        _gitleaksRule(ids[3]).hasMatch(r'storePassword=$System.env.KS_PASS'),
        isFalse,
      );
    });

    // BUG-4: a password hard-coded in a Gradle script, the likeliest leak
    // (android/app/build.gradle.kts is where signing is configured), passes
    // the custom rule: it excludes quotes from the value. The hygiene test
    // does not scan build scripts at all (it reads android/app/src only).
    for (final line in [
      '        storePassword = "hunter2hunter2"',
      "    keyPassword 'hunter2hunter2'",
      '        keyPassword = "S3cr3t!Pass"',
    ]) {
      test('a hard-coded Gradle signing password is caught: $line', () {
        expect(_gitleaksRule(ids[3]).hasMatch(line), isTrue);
      });
    }

    // BUG-5: top-level [[allowlists]] needs gitleaks >= 8.25.0. The pinned
    // gitleaks-action v3.0.0 installs 8.24.3 unless GITLEAKS_VERSION is set
    // (src/index.js:138), and 8.24.3 only reads [allowlist], so the table is
    // silently ignored.
    test('the allowlist syntax matches the gitleaks version CI runs', () {
      final toml = File('.gitleaks.toml').readAsStringSync();
      if (!toml.contains('[[allowlists]]')) return;
      final ci = File('.github/workflows/ci.yml').readAsStringSync();
      final version = RegExp(r'GITLEAKS_VERSION:\s*"?v?(\d+)\.(\d+)')
          .firstMatch(ci);
      expect(version, isNotNull, reason: 'GITLEAKS_VERSION is not set');
      final major = int.parse(version!.group(1)!);
      final minor = int.parse(version.group(2)!);
      expect(major > 8 || (major == 8 && minor >= 25), isTrue);
    });
  });

  // Round 2: forms that still pass the fixed patterns.
  group('R2-1: cleartext and console forms still missed', () {
    const cleartext = "test('no cleartext URLs'";
    const console = "test('no print or debugPrint";
    final cases = <(String, String, String)>[
      ('split before the colon', cleartext, "const u = 'http' '://api.x.pk';"),
      (
        'Uri with a ws scheme',
        cleartext,
        "final u = Uri(scheme: 'ws', host: 'api.x.pk');",
      ),
      (
        'stdout cascade on the next line (dart format output)',
        console,
        'stdout\n    ..write(token)\n    ..write(phone);',
      ),
      ('stdout through a variable', console, 'final IOSink out = stdout;'),
    ];
    for (final (name, anchor, code) in cases) {
      test(name, () {
        expect(_hygieneCatches(code, anchor), isTrue, reason: code);
      });
    }
  });

  group('R2-2: signing passwords that still pass both checks', () {
    final hygiene = _hygienePattern("test('no secret keys").regExp;
    for (final line in [
      // A key.properties copy whose password contains a dollar sign.
      r'storePassword=Pa$$w0rd2026',
      // Kotlin fallback after an environment variable.
      '        storePassword = System.getenv("KS_PASS") ?: "hunter2hunter2"',
      // A trailing comment after the value.
      '        keyPassword = "hunter2hunter2" // TODO: move to CI',
    ]) {
      test('caught: $line', () {
        expect(
          _gitleaksRule('android-signing-password').hasMatch(line),
          isTrue,
          reason: 'gitleaks',
        );
        expect(hygiene.hasMatch(line), isTrue, reason: 'hygiene test');
      });
    }
  });
}
