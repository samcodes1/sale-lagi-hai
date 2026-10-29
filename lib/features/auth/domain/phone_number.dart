/// Pakistani mobile numbers, the only phones the app signs in with.
///
/// People type them many ways: `0300 1234567`, `300-1234567`,
/// `+92 300 1234567`, `0092…`, and with Urdu keyboards in Eastern Arabic
/// digits (`۰۳۰۰…`). All become E.164 (`+923001234567`) or `null`.
abstract final class PakistanPhone {
  // Spaces, dashes, brackets, dots, and the invisible direction marks and
  // isolates that copy-pasting from right-to-left text carries along.
  static final _separators = RegExp(
    '[\\s\\-().\u200E\u200F\u2066\u2067\u2068\u2069]',
  );
  static final _mobile = RegExp(r'^3[0-9]{9}$');

  /// The number in E.164, or `null` if it isn't a Pakistani mobile number.
  static String? toE164(String input) {
    var digits = _asciiDigits(input).replaceAll(_separators, '');
    if (digits.startsWith('+92')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0092')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('92') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _mobile.hasMatch(digits) ? '+92$digits' : null;
  }

  /// For showing a signed-in number without exposing all of it:
  /// `+92 300 ••• ••67`. Anything that isn't E.164 Pakistani is fully
  /// masked.
  static String masked(String e164) {
    final local = e164.startsWith('+92') ? e164.substring(3) : '';
    if (!_mobile.hasMatch(local)) return '•••';
    return '+92 ${local.substring(0, 3)} ••• ••${local.substring(8)}';
  }

  /// The number as people read it: `+92 300 1234567`.
  static String display(String e164) {
    final local = e164.startsWith('+92') ? e164.substring(3) : '';
    if (!_mobile.hasMatch(local)) return e164;
    return '+92 ${local.substring(0, 3)} ${local.substring(3)}';
  }

  /// Maps Arabic-Indic (U+0660…) and Extended Arabic-Indic (U+06F0…, the
  /// ones Urdu keyboards type) digits to ASCII.
  static String _asciiDigits(String input) => String.fromCharCodes(
    input.runes.map((r) {
      if (r >= 0x0660 && r <= 0x0669) return r - 0x0660 + 0x30;
      if (r >= 0x06F0 && r <= 0x06F9) return r - 0x06F0 + 0x30;
      return r;
    }),
  );
}
