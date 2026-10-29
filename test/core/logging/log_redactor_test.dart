import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/logging/log_redactor.dart';

void main() {
  const redactor = LogRedactor();

  group('redact() removes', () {
    final cases = <String, String>{
      // Phone numbers in every common Pakistani format.
      'call 03001234567 now': 'call [phone] now',
      'call 0300-1234567': 'call [phone]',
      'call 0300 1234567': 'call [phone]',
      'call +923001234567': 'call [phone]',
      'call +92 300 1234567': 'call [phone]',
      'call +92-300-1234567': 'call [phone]',
      'call 00923001234567': 'call [phone]',
      'call 923001234567': 'call [phone]',
      'call 0300-123-4567': 'call [phone]',
      // Emails.
      'from ali.khan+deals@example.com.pk': 'from [email]',
      // Card numbers.
      'card 4111111111111111': 'card [card]',
      'card 4111 1111 1111 1111': 'card [card]',
      'card 4111-1111-1111-1111': 'card [card]',
      // CNIC.
      'cnic 42101-1234567-1': 'cnic [cnic]',
      // Tokens and keys.
      'token eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.abc-_123': 'token [jwt]',
      'key sb_secret_abcDEF123': 'key [key]',
      'key sb_publishable_abc_123': 'key [key]',
      'Authorization: Bearer abc.def.ghi': 'Authorization: Bearer [token]',
      'authorization: bearer xyz': 'authorization: Bearer [token]',
      // Precise coordinates.
      'at 24.86073, 67.00114': 'at [location]',
      'at -33.865,151.209': 'at [location]',
    };

    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () => expect(redactor.redact(input), expected));
    }
  });

  group('redact() leaves ordinary deal text alone', () {
    for (final text in [
      'Rs 2,999 (was Rs 4,999)',
      'Flat 40% off till 31 Oct',
      'Valid 2026-10-29 to 2026-11-30',
      'Deal 3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f loaded in 120ms',
      'Sapphire sale page 2 of 12',
      'Rating 4.5, 120 reviews',
      'City-level location 24.86, 67.00',
    ]) {
      test(text, () => expect(redactor.redact(text), text));
    }
  });

  test('handles several secrets in one message', () {
    expect(
      redactor.redact('user a@b.co phone 03001234567 at 24.861, 67.001'),
      'user [email] phone [phone] at [location]',
    );
  });

  group('redactContext()', () {
    test('hides values of sensitive keys entirely', () {
      final result = redactor.redactContext({
        'accessToken': 'abc',
        'refresh_token': 'abc',
        'apiKey': 'abc',
        'phoneNumber': 'abc',
        'user-email': 'abc',
        'lat': 24.8,
        'Authorization': 'abc',
        'searchQuery': 'abc',
        'cardNumber': 'abc',
      });

      expect(result.values, everyElement('[redacted]'));
    });

    test('keeps ordinary keys, redacting their values', () {
      final result = redactor.redactContext({
        'dealId': 'd-1',
        'relatedId': 'r-1',
        'translationKeyCount': 3,
        'categories': 'food',
        'cardType': 'visa',
        'note': 'sent to 03001234567',
        'missing': null,
      });

      expect(result, {
        'dealId': 'd-1',
        'relatedId': 'r-1',
        'translationKeyCount': '[redacted]',
        'categories': 'food',
        'cardType': 'visa',
        'note': 'sent to [phone]',
        'missing': 'null',
      });
    });
  });

  test('isSensitiveKey splits camelCase, snake_case and dashes', () {
    expect(LogRedactor.isSensitiveKey('fcmToken'), isTrue);
    expect(LogRedactor.isSensitiveKey('user_phone'), isTrue);
    expect(LogRedactor.isSensitiveKey('x-session-id'), isTrue);
    expect(LogRedactor.isSensitiveKey('OTP'), isTrue);
    expect(LogRedactor.isSensitiveKey('relatedId'), isFalse);
    expect(LogRedactor.isSensitiveKey('platform'), isFalse);
    expect(LogRedactor.isSensitiveKey('keyboardType'), isFalse);
  });
}
