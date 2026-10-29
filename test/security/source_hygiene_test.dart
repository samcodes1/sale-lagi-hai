// Source checks for the security baseline (sub-phase 1.7). They scan the
// app's code, config templates and assets for patterns that leak data or
// weaken transport security. See docs/security/CHECKLIST.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hand-written app code (generated l10n and route files excluded).
final List<File> _libFiles = [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File &&
        f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.contains('l10n${Platform.pathSeparator}gen'))
      f,
];

/// Everything that ships or configures a build: code, env templates,
/// assets and Android resources.
final List<File> _shippedFiles = [
  ..._libFiles,
  for (final dir in ['env', 'assets', 'android/app/src'])
    for (final f in Directory(dir).listSync(recursive: true))
      if (f is File && !_binary.any(f.path.endsWith)) f,
];

const _binary = ['.ttf', '.otf', '.png', '.jpg', '.webp', '.jar', '.so'];

/// The source without `//` comments (doc comments may name a pattern).
String _code(File f) => f.readAsStringSync().replaceAll(
  RegExp(r'^\s*//.*$|\s//.*$', multiLine: true),
  '',
);

List<String> _matches(
  Iterable<File> files,
  RegExp pattern, {
  bool code = true,
}) => [
  for (final f in files)
    for (final m in pattern.allMatches(code ? _code(f) : f.readAsStringSync()))
      '${f.path}: ${m[0]}',
];

void main() {
  test('scans real files', () {
    expect(_libFiles.length, greaterThan(20));
    expect(_shippedFiles.length, greaterThan(_libFiles.length));
  });

  test('no print or debugPrint outside the console log sink', () {
    // Logs go through AppLogger, which redacts personal data. Only the
    // console sink writes to the console.
    final offenders = _matches(
      _libFiles.where((f) => !f.path.endsWith('log_sinks.dart')),
      RegExp(r'\b(print|debugPrint|debugPrintStack)\b|\bstd(out|err)\.'),
    );
    expect(offenders, isEmpty);
  });

  test('no cleartext URLs', () {
    final offenders = _matches(
      _shippedFiles.where((f) => !f.path.endsWith('.xml')),
      RegExp(r'http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2)'),
    );
    expect(offenders, isEmpty);
  });

  test('no TLS or certificate bypass', () {
    final offenders = _matches(
      _libFiles,
      RegExp(r'badCertificateCallback|HttpOverrides|SecurityContext\('),
    );
    expect(offenders, isEmpty);
  });

  test('no secret keys or tokens in code, templates or assets', () {
    final offenders = _matches(
      _shippedFiles,
      code: false,
      RegExp(
        // Supabase secret keys, any JWT, private key blocks, keystore
        // passwords and Google API keys.
        'sb_secret_[A-Za-z0-9_-]{8,}'
        r'|eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'
        '|-----BEGIN [A-Z ]*PRIVATE KEY-----'
        r'|(store|key)Password\s*=\s*\S+'
        '|AIza[0-9A-Za-z_-]{35}',
      ),
    );
    expect(offenders, isEmpty);
  });

  test('no code loaded or evaluated at runtime', () {
    final offenders = _matches(
      _libFiles,
      RegExp(r"'dart:mirrors'|Isolate\.spawnUri|loadLibrary\(\)"),
    );
    expect(offenders, isEmpty);
  });

  test('the checks catch what they ban', () {
    final dir = Directory.systemTemp.createTempSync('hygiene');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.dart')
      ..writeAsStringSync('''
// print('a comment is fine');
void f() { print('leak'); debugPrint('x'); }
const url = 'http://example.com';
const key = 'sb_secret_abcdefghijkl';
''');
    expect(_matches([bad], RegExp(r'\b(print|debugPrint)\b')), hasLength(2));
    expect(_matches([bad], RegExp('http://')), hasLength(1));
    expect(
      _matches([bad], RegExp('sb_secret_[A-Za-z0-9_-]{8,}'), code: false),
      hasLength(1),
    );
  });
}
