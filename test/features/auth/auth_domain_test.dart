import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/phone_number.dart';

void main() {
  group('PakistanPhone.toE164', () {
    test('accepts the ways people type a mobile number', () {
      for (final input in [
        '03001234567',
        '0300 1234567',
        '0300-1234567',
        '300 123 4567',
        '+92 300 1234567',
        '+923001234567',
        '00923001234567',
        '923001234567',
        '(0300) 123-4567',
        '۰۳۰۰۱۲۳۴۵۶۷', // Urdu keyboard
        '٠٣٠٠١٢٣٤٥٦٧', // Arabic-Indic
        '\u2066+92 300 1234567\u2069', // pasted from right-to-left text
      ]) {
        expect(PakistanPhone.toE164(input), '+923001234567', reason: input);
      }
    });

    test('rejects landlines, foreign and malformed numbers', () {
      for (final input in [
        '',
        '021 34567890', // Karachi landline
        '0300123456', // one digit short
        '030012345678', // one too many
        '+44 7700 900123',
        '+92 21 3456 7890',
        'abc',
        '0300 12345 67x',
      ]) {
        expect(PakistanPhone.toE164(input), isNull, reason: input);
      }
    });

    test('masked hides the middle; display groups the digits', () {
      expect(PakistanPhone.masked('+923001234567'), '+92 300 ••• ••67');
      expect(PakistanPhone.masked('+447700900123'), '•••');
      expect(PakistanPhone.display('+923001234567'), '+92 300 1234567');
      expect(PakistanPhone.display('garbage'), 'garbage');
    });
  });

  group('AppUser', () {
    test('toString holds no personal data', () {
      const user = AppUser(
        id: 'u1',
        method: SignInMethod.phone,
        phone: '+923001234567',
      );
      expect(user.toString(), isNot(contains('300')));
      expect(user.toString(), isNot(contains('u1')));
      expect(
        user,
        const AppUser(
          id: 'u1',
          method: SignInMethod.phone,
          phone: '+923001234567',
        ),
      );
    });
  });

  group('DemoAuthRepository', () {
    const phone = '+923001234567';
    late DateTime now;
    late DemoAuthRepository auth;

    setUp(() {
      now = DateTime.utc(2026, 10, 29, 12);
      auth = DemoAuthRepository(clock: () => now);
    });

    test('a sent code signs in; the user stream follows', () async {
      final events = <AppUser?>[];
      final sub = auth.userChanges().listen(events.add);
      expect((await auth.sendPhoneCode(phone)).isSuccess, isTrue);
      final user = (await auth.verifyPhoneCode(
        phone,
        DemoAuthRepository.code,
      )).valueOrNull;
      expect(user?.phone, phone);
      expect(user?.method, SignInMethod.phone);
      expect(auth.currentUser, user);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(events, [null, user, null]);
      await sub.cancel();
    });

    test('a wrong, unsent or expired code is a validation failure', () async {
      Matcher invalidCode() => isA<Failure<AppUser>>().having(
        (f) => f.failure,
        'failure',
        isA<ValidationFailure>().having((v) => v.fieldErrors, 'fields', {
          'code': 'invalid',
        }),
      );
      expect(
        await auth.verifyPhoneCode(phone, DemoAuthRepository.code),
        invalidCode(),
      );
      await auth.sendPhoneCode(phone);
      expect(await auth.verifyPhoneCode(phone, '000000'), invalidCode());
      now = now.add(const Duration(minutes: 11));
      expect(
        await auth.verifyPhoneCode(phone, DemoAuthRepository.code),
        invalidCode(),
      );
    });

    test('five codes an hour per number, then rate limited', () async {
      for (var i = 0; i < 5; i++) {
        expect((await auth.sendPhoneCode(phone)).isSuccess, isTrue);
      }
      final limited = await auth.sendPhoneCode(phone);
      expect(limited.failureOrNull, isA<RateLimitedFailure>());
      expect(
        (limited.failureOrNull! as RateLimitedFailure).retryAfter,
        const Duration(hours: 1),
      );
      expect((await auth.sendPhoneCode('+923331234567')).isSuccess, isTrue);
      now = now.add(const Duration(hours: 1));
      expect((await auth.sendPhoneCode(phone)).isSuccess, isTrue);
    });

    test('deletion needs a sign-in in the last 5 minutes', () async {
      expect(
        (await auth.deleteAccount()).failureOrNull,
        isA<UnauthorizedFailure>(),
      );
      await auth.sendPhoneCode(phone);
      await auth.verifyPhoneCode(phone, DemoAuthRepository.code);
      now = now.add(const Duration(minutes: 6));
      expect(
        (await auth.deleteAccount()).valueOrNull,
        DeletionOutcome.reauthRequired,
      );
      expect(auth.currentUser, isNotNull);
      await auth.sendPhoneCode(phone);
      await auth.verifyPhoneCode(phone, DemoAuthRepository.code);
      expect((await auth.deleteAccount()).valueOrNull, DeletionOutcome.deleted);
      expect(auth.currentUser, isNull);
    });

    test('Google: a demo account when available, refused when not', () async {
      final user = (await auth.signInWithGoogle()).valueOrNull;
      expect(user?.method, SignInMethod.google);
      expect(user?.email, isNotNull);
      final off = DemoAuthRepository(googleAvailable: false);
      expect(off.canUseGoogle, isFalse);
      expect(
        (await off.signInWithGoogle()).failureOrNull,
        isA<ForbiddenFailure>(),
      );
    });
  });
}
