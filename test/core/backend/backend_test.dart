import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/secure_session_storage.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

AppFailure? _map(Object error) => backendErrorMapper(error, StackTrace.empty);

void main() {
  group('backendErrorMapper', () {
    test('Postgres and PostgREST codes', () {
      expect(
        _map(const PostgrestException(message: 'x', code: '42501')),
        isA<ForbiddenFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: 'PGRST301')),
        isA<UnauthorizedFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: 'PT429')),
        isA<RateLimitedFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: '23514')),
        isA<ValidationFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: '22023')),
        isA<ValidationFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: '55000')),
        isA<ValidationFailure>(),
      );
      expect(
        _map(const PostgrestException(message: 'x', code: 'PGRST116')),
        isA<NotFoundFailure>(),
      );
      final server = _map(const PostgrestException(message: 'x', code: '500'));
      expect(
        server,
        isA<ServerFailure>().having((f) => f.isRetryable, 'retryable', isTrue),
      );
    });

    test('auth errors', () {
      expect(
        _map(const AuthException('slow down', statusCode: '429')),
        isA<RateLimitedFailure>(),
      );
      expect(
        _map(const AuthException('expired', statusCode: '401')),
        isA<UnauthorizedFailure>(),
      );
      expect(
        _map(const AuthException('bad otp', statusCode: '422')),
        isA<ValidationFailure>(),
      );
      expect(
        _map(AuthRetryableFetchException(message: 'offline')),
        isA<OfflineFailure>(),
      );
    });

    test('network errors', () {
      expect(_map(const SocketException('no route')), isA<OfflineFailure>());
      expect(_map(TimeoutException('slow')), isA<TimeoutFailure>());
    });

    test('anything else is left for other mappers', () {
      expect(_map(StateError('bug')), isNull);
    });

    test('the cause is kept for logs but never in the message', () {
      final f = _map(
        const PostgrestException(message: 'secret details', code: '42501'),
      )!;
      expect(f.toString(), isNot(contains('secret')));
      expect(f.cause, isA<PostgrestException>());
    });
  });

  group('SecureSessionStorage', () {
    test('keeps the session in secure storage', () async {
      final store = InMemorySecureStore();
      final storage = SecureSessionStorage(store);
      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession('{"access_token":"t"}');
      expect(store.values[SecureKey.authSession], '{"access_token":"t"}');
      expect(await storage.accessToken(), '{"access_token":"t"}');
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    });
  });

  group('SecurePkceStorage', () {
    test(
      'stores verifiers by key in one secure entry, and cleans up',
      () async {
        final store = InMemorySecureStore();
        final pkce = SecurePkceStorage(store);
        await pkce.setItem(key: 'sb-code-verifier', value: 'v1');
        await pkce.setItem(key: 'other', value: 'v2');
        expect(await pkce.getItem(key: 'sb-code-verifier'), 'v1');
        await pkce.removeItem(key: 'sb-code-verifier');
        expect(await pkce.getItem(key: 'sb-code-verifier'), isNull);
        await pkce.removeItem(key: 'other');
        expect(store.values.containsKey(SecureKey.authPkce), isFalse);
      },
    );

    test('a corrupted entry reads as empty', () async {
      final store = InMemorySecureStore()
        ..values[SecureKey.authPkce] = 'not json';
      expect(await SecurePkceStorage(store).getItem(key: 'x'), isNull);
    });
  });
}
