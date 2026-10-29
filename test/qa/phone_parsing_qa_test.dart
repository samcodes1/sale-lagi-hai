// QA (sub-phase 4.2 gate): PakistanPhone edge cases beyond the
// developer's list. S4 findings are skipped with their bug id.
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/features/auth/domain/phone_number.dart';

// Right-to-left embedding and pop directional formatting.
final _rle = String.fromCharCode(0x202B);
final _pdf = String.fromCharCode(0x202C);

void main() {
  test('more ways people type or paste a mobile number', () {
    for (final input in [
      '+92-300-1234567',
      '+92 (300) 123 4567',
      '0 300 1234567',
      '0300\u00A01234567', // no-break space
      '0300.123.4567',
      '  03001234567  ',
      '\u200F0300 1234567\u200F', // right-to-left marks
      '+۹۲ ۳۰۰ ۱۲۳۴۵۶۷', // Urdu digits with +92
      '۰۰۹۲۳۰۰۱۲۳۴۵۶۷',
    ]) {
      expect(PakistanPhone.toE164(input), '+923001234567', reason: input);
    }
  });

  test('never accepts what is not a Pakistani mobile', () {
    for (final input in [
      '+92 300 1234567 8', // one digit too many
      '92300123456', // 11 digits starting 92, one short
      '+1 300 1234567',
      '++923001234567',
      '+92+3001234567',
      '300123456',
      '0800 1234567', // toll-free, not mobile
      // Round 2: dropping the trunk 0 after +92 must not open these up.
      '00300 1234567',
      '+92 00300 1234567',
      '0923001234567',
      '920300 1234567',
      '+92 300 12345x7',
      '٣٠٠١٢٣٤٥٦٧٨٩', // 12 Arabic-Indic digits
      '1' * 10000,
    ]) {
      expect(PakistanPhone.toE164(input), isNull, reason: input);
    }
  });

  test('masked and display never throw on odd input', () {
    for (final input in ['', '+', '+92', '+9230012345678', 'x' * 1000]) {
      expect(PakistanPhone.masked(input), '•••', reason: input);
      expect(() => PakistanPhone.display(input), returnsNormally);
    }
    // The masked form keeps exactly 5 of the 10 local digits.
    final masked = PakistanPhone.masked('+923451234598');
    expect(masked, '+92 345 ••• ••98');
    expect(RegExp(r'\d').allMatches(masked.substring(4)).length, 5);
  });

  // QA BUG 4.2-A13 (S4): "+92 0300 1234567" (the trunk 0 kept after +92,
  // a common way to write it) and numbers pasted with the bidi embedding
  // controls U+202A–U+202E are refused (phone_number.dart:9-25). The log
  // redactor already strips U+202A–U+202E.
  test(
    'QA BUG 4.2-A13: +92 with the trunk 0, and pasted embedding controls',
    () {
      expect(PakistanPhone.toE164('+92 0300 1234567'), '+923001234567');
      // 0092 is +92, so the trunk 0 after it is fine too (moved here from
      // the reject list when A13 was fixed).
      expect(PakistanPhone.toE164('0092 0300 1234567'), '+923001234567');
      expect(PakistanPhone.toE164('${_rle}0300 1234567$_pdf'), '+923001234567');
    },
  );
}
