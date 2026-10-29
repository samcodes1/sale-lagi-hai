/// Spotting payment card numbers in free text, so the app never sends one
/// (QA 4.7-P1). The same rule as the database's
/// `private.contains_card_number`: a run of 13 to 19 digits (spaces or
/// dashes between) that passes the Luhn check, as a whole or in its first
/// or last 15 or 16 digits.
abstract final class CardNumbers {
  static final _runs = RegExp(r'(?:\d[ -]?){12,}\d');

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
    for (final match in _runs.allMatches(text)) {
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
