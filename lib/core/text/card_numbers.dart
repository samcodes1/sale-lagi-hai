/// Spotting payment card numbers in free text, so the app never sends one
/// (QA 4.7-P1). The same rule as the database's
/// `private.contains_card_number`: a run of 13 to 19 digits (Western, Urdu
/// or Arabic-Indic; spaces, dots or a dash between the groups) that passes
/// the Luhn check, as a whole or in its first or last 15 or 16 digits.
abstract final class CardNumbers {
  static final _runs = RegExp('(?:[0-9](?:[ .]{1,2}| ?- ?)?){12,}[0-9]');

  /// Urdu (U+06F0..9) and Arabic-Indic (U+0660..9) digits as Western ones
  /// (QA 4.9-C1).
  static String _western(String text) => String.fromCharCodes([
    for (final c in text.runes)
      if (c >= 0x06F0 && c <= 0x06F9)
        c - 0x06F0 + 0x30
      else if (c >= 0x0660 && c <= 0x0669)
        c - 0x0660 + 0x30
      else
        c,
  ]);

  static bool _luhn(String digits) {
    var total = 0;
    for (var i = 0; i < digits.length; i++) {
      var d = digits.codeUnitAt(digits.length - 1 - i) - 0x30;
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      total += d;
    }
    return total % 10 == 0;
  }

  static bool containsOne(String text) {
    for (final match in _runs.allMatches(_western(text))) {
      final digits = match[0]!.replaceAll(RegExp('[^0-9]'), '');
      if (digits.length >= 13 && digits.length <= 19 && _luhn(digits)) {
        return true;
      }
      for (final n in const [15, 16]) {
        if (digits.length > n &&
            (_luhn(digits.substring(0, n)) ||
                _luhn(digits.substring(digits.length - n)))) {
          return true;
        }
      }
    }
    return false;
  }
}
