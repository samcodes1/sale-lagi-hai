import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/text/card_numbers.dart';

void main() {
  test('a card number is spotted, however it is spaced', () {
    for (final text in [
      '4111111111111111',
      'my card 4111 1111 1111 1111 was refused',
      '4111-1111-1111-1111',
      // 15 digits (Amex)
      '378282246310005',
      // A valid 16 inside a longer run, at either end.
      '41111111111111119',
      '94111111111111111',
      // Urdu and Arabic-Indic digits, and other separators (QA 4.9-C1/C2).
      'کارڈ ۴۱۱۱ ۱۱۱۱ ۱۱۱۱ ۱۱۱۱',
      '٤١١١١١١١١١١١١١١١',
      '4111.1111.1111.1111',
      '4111 - 1111 - 1111 - 1111',
    ]) {
      expect(CardNumbers.containsOne(text), isTrue, reason: text);
    }
  });

  test('ordinary numbers are not card numbers', () {
    for (final text in [
      '',
      'Flat 40% off, Rs 2,999',
      '0300 1234567',
      '+923001234567',
      // 16 digits failing the Luhn check.
      '4111111111111112',
      // 12 digits: too short.
      '411111111111',
      'Order 2026-10-30 at 22:00',
      'کال کریں ۰۳۰۰ ۱۲۳۴۵۶۷',
      'Rs 1.299 off, was Rs 2,999',
    ]) {
      expect(CardNumbers.containsOne(text), isFalse, reason: text);
    }
  });
}
