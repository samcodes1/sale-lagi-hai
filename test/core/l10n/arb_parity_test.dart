import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Placeholder names used in an ICU message, e.g. `{count}` and `{date}`
/// (but not plural keywords like `=1{` or `other{`).
Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)[,}]').allMatches(message)) m[1]!,
};

/// The plural selectors a message defines, e.g. {=0, =1, other}.
Set<String> _pluralCases(String message) => {
  for (final m in RegExp(
    r'(=\d+|zero|one|two|few|many|other)\{',
  ).allMatches(message))
    m[1]!,
};

void main() {
  final en = _arb('en');
  final ur = _arb('ur');

  test('both files declare their locale', () {
    expect(en['@@locale'], 'en');
    expect(ur['@@locale'], 'ur');
  });

  test('Urdu has exactly the English keys (no missing, no extra)', () {
    final enKeys = _messageKeys(en)..remove('@@locale');
    final urKeys = _messageKeys(ur)..remove('@@locale');

    expect(urKeys.difference(enKeys), isEmpty, reason: 'only in Urdu');
    expect(enKeys.difference(urKeys), isEmpty, reason: 'missing in Urdu');
  });

  test('every message is non-empty', () {
    for (final arb in [en, ur]) {
      for (final key in _messageKeys(arb)) {
        expect((arb[key]! as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('placeholders and plural cases match between languages', () {
    for (final key in _messageKeys(en)) {
      if (key == '@@locale') continue;
      final enMessage = en[key]! as String;
      final urMessage = ur[key]! as String;
      expect(_placeholders(urMessage), _placeholders(enMessage), reason: key);
      expect(_pluralCases(urMessage), _pluralCases(enMessage), reason: key);
    }
  });

  test('every placeholder is declared with a type in the template', () {
    for (final key in _messageKeys(en)) {
      if (key == '@@locale') continue;
      final used = _placeholders(en[key]! as String);
      if (used.isEmpty) continue;
      final meta = en['@$key'] as Map<String, Object?>?;
      final declared =
          (meta?['placeholders'] as Map<String, Object?>?) ?? const {};
      for (final name in used) {
        expect(declared.keys, contains(name), reason: '$key {$name}');
        final type = (declared[name]! as Map<String, Object?>)['type'];
        expect(type, isNotNull, reason: '$key {$name} needs a type');
      }
    }
  });

  test('Urdu strings are in Urdu script, not Roman Urdu', () {
    // Keys with no letters to translate: the English language name, and
    // the discount badge (a number and symbols).
    // welcomeLanguagePromptOther is the prompt in the other language, so
    // the first screen speaks to both readers (checked below).
    const latinAllowed = {
      'languageEnglish',
      'discountBadge',
      'welcomeLanguagePromptOther',
    };
    final urduLetters = RegExp('[؀-ۿ]');
    for (final key in _messageKeys(ur)) {
      if (key == '@@locale' || latinAllowed.contains(key)) continue;
      expect(
        urduLetters.hasMatch(ur[key]! as String),
        isTrue,
        reason: '$key has no Urdu letters',
      );
    }
  });

  test('the Urdu language name is written in Urdu in both files', () {
    expect(en['languageUrdu'], 'اردو');
    expect(ur['languageUrdu'], 'اردو');
    expect(ur['languageEnglish'], 'English');
    expect(ur['welcomeLanguagePromptOther'], en['welcomeLanguagePrompt']);
    expect(en['welcomeLanguagePromptOther'], ur['welcomeLanguagePrompt']);
  });
}
