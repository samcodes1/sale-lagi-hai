import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Material widgets whose defaults break our contrast or text-size rules in
/// ways no theme can reach. App code uses the design-system replacement;
/// only `lib/design_system/` may touch the raw widget.
///
/// See docs/qa/1.3.md (round 2) for each finding.
const _banned = <String, String>{
  r'\bTabBar\(': 'AppTabBar (tabs grow with the text size)',
  r'\bRefreshIndicator(\.adaptive)?\(': 'AppRefreshIndicator',
  r'\bStepper\(': 'AppStepper (readable step circles)',
  r'\bshowDateRangePicker\(': 'showAppDateRangePicker',
};

void main() {
  final sources = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File &&
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.contains(
            '${Platform.pathSeparator}design_system'
            '${Platform.pathSeparator}',
          ) &&
          !f.path.contains(
            '${Platform.pathSeparator}l10n'
            '${Platform.pathSeparator}gen${Platform.pathSeparator}',
          ))
        f,
  ];

  test('scans the app code', () {
    expect(sources, isNotEmpty);
  });

  for (final MapEntry(key: pattern, value: replacement) in _banned.entries) {
    test('no raw ${pattern.replaceAll(RegExp(r'[\\()?.b]'), '')} '
        'outside the design system', () {
      final offenders = [
        for (final f in sources)
          if (RegExp(pattern).hasMatch(_code(f.readAsStringSync()))) f.path,
      ];
      expect(offenders, isEmpty, reason: 'Use $replacement instead.');
    });
  }

  test('toggle IconButtons sit under AccentPrimary', () {
    // `isSelected:` makes IconButton paint `primary` (yellow) as the icon
    // colour or a thin mark. Toggles live in the design system, wrapped in
    // AccentPrimary.
    final offenders = [
      for (final f in sources)
        for (final call in _calls(f, RegExp(r'\bIconButton(\.\w+)?\(')))
          if (call.contains('isSelected:')) '${f.path}: $call',
    ];
    expect(offenders, isEmpty);
  });

  test('SwitchListTile is never `selected:`', () {
    // A selected SwitchListTile colours its title from the switch's thumb
    // (QA 1.3 R2-5). Selection is shown by the switch itself.
    final offenders = [
      for (final f in sources)
        for (final call in _calls(f, RegExp(r'\bSwitchListTile(\.\w+)?\(')))
          if (RegExp(r'\bselected:').hasMatch(call)) '${f.path}: $call',
    ];
    expect(offenders, isEmpty);
  });

  test('the checks catch what they ban', () {
    const sample = '''
      // TabBar( in a comment is fine
      final a = IconButton.filled(isSelected: true, onPressed: f(x), icon: i);
      final b = SwitchListTile(value: v, selected: true, onChanged: g);
    ''';
    expect(RegExp(r'\bTabBar\(').hasMatch(_code(sample)), isFalse);
    expect(
      _callsIn(_code(sample), RegExp(r'\bIconButton(\.\w+)?\(')).single,
      contains('isSelected:'),
    );
    expect(
      _callsIn(_code(sample), RegExp(r'\bSwitchListTile(\.\w+)?\(')).single,
      contains('selected:'),
    );
  });
}

/// The source without `//` comments, so docs may name the raw widgets.
String _code(String source) =>
    source.replaceAll(RegExp(r'//.*$', multiLine: true), '');

Iterable<String> _calls(File f, RegExp start) =>
    _callsIn(_code(f.readAsStringSync()), start);

/// The text of each call matching [start], up to its closing parenthesis.
Iterable<String> _callsIn(String code, RegExp start) sync* {
  for (final m in start.allMatches(code)) {
    var depth = 0;
    for (var i = m.end - 1; i < code.length; i++) {
      final c = code[i];
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) {
        yield code.substring(m.start, i + 1);
        break;
      }
    }
  }
}
