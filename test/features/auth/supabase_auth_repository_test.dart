import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/data/google_id_token.dart';
import 'package:sale_lagi_hai/features/auth/data/supabase_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _phone = '+923001234567';

/// A session response as GoTrue returns it.
Map<String, Object?> _session({
  String provider = 'phone',
  String? phone = '923001234567',
  String? email,
}) => {
  'access_token': 'header.payload.signature',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': '7a1c2f3e-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'role': 'authenticated',
    'phone': phone,
    'email': email,
    'app_metadata': {'provider': provider},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-10-29T12:00:00Z',
  },
};

final class _FakeGoogle implements GoogleIdTokenSource {
  new(this.token);

  final String? token;
  int signOuts = 0;

  @override
  Future<String?> idToken() async => token;

  @override
  Future<void> signOut() async => signOuts++;
}

typedef _Handler = Future<http.Response> Function(http.Request request);

({SupabaseAuthRepository auth, List<http.Request> requests}) _repo(
  _Handler handler, {
  GoogleIdTokenSource? google,
}) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://p.supabase.co',
    'sb_publishable_test',
    httpClient: MockClient((request) {
      requests.add(request);
      return handler(request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(client.dispose);
  return (
    auth: SupabaseAuthRepository(client, AppLogger(sinks: []), google: google),
    requests: requests,
  );
}

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('sending a code posts the number to /otp', () async {
    final r = _repo((_) async => _json(200, <String, Object?>{}));
    expect((await r.auth.sendPhoneCode(_phone)).isSuccess, isTrue);
    final request = r.requests.single;
    expect(request.url.path, '/auth/v1/otp');
    expect((jsonDecode(request.body) as Map)['phone'], _phone);
  });

  test('a number the provider rejects is a phone validation failure', () async {
    final r = _repo(
      (_) async => _json(400, {
        'code': 'validation_failed',
        'msg': 'Invalid phone number format',
      }),
    );
    final failure = (await r.auth.sendPhoneCode(_phone)).failureOrNull;
    expect(
      failure,
      isA<ValidationFailure>().having((f) => f.fieldErrors, 'fields', {
        'phone': 'invalid',
      }),
    );
  });

  test('too many codes is rate limited', () async {
    final r = _repo(
      (_) async => _json(429, {
        'code': 'over_sms_send_rate_limit',
        'msg': 'For security purposes, you can only request this after 60s.',
      }),
    );
    expect(
      (await r.auth.sendPhoneCode(_phone)).failureOrNull,
      isA<RateLimitedFailure>(),
    );
  });

  test('a right code signs in a phone user (with the + restored)', () async {
    final r = _repo((_) async => _json(200, _session()));
    final user = (await r.auth.verifyPhoneCode(_phone, '123456')).valueOrNull;
    expect(user?.method, SignInMethod.phone);
    expect(user?.phone, _phone);
    expect(r.auth.currentUser, user);
    final body = jsonDecode(r.requests.single.body) as Map;
    expect(body['type'], 'sms');
    expect(body['token'], '123456');
  });

  test('a wrong or expired code is a code validation failure', () async {
    final r = _repo(
      (_) async => _json(403, {
        'code': 'otp_expired',
        'msg': 'Token has expired or is invalid',
      }),
    );
    expect(
      (await r.auth.verifyPhoneCode(_phone, '000000')).failureOrNull,
      isA<ValidationFailure>().having((f) => f.fieldErrors, 'fields', {
        'code': 'invalid',
      }),
    );
  });

  group('Google', () {
    test('trades the ID token for a session', () async {
      final r = _repo(
        (_) async => _json(
          200,
          _session(provider: 'google', phone: null, email: 'a@b.pk'),
        ),
        google: _FakeGoogle('google-id-token'),
      );
      expect(r.auth.canUseGoogle, isTrue);
      final user = (await r.auth.signInWithGoogle()).valueOrNull;
      expect(user?.method, SignInMethod.google);
      expect(user?.email, 'a@b.pk');
      expect(user?.phone, isNull);
      final request = r.requests.single;
      expect(request.url.queryParameters['grant_type'], 'id_token');
      expect((jsonDecode(request.body) as Map)['id_token'], 'google-id-token');
    });

    test('closing the sheet is not an error, and calls nothing', () async {
      final r = _repo(
        (_) async => fail('no request expected'),
        google: _FakeGoogle(null),
      );
      expect(await r.auth.signInWithGoogle(), const Success<AppUser?>(null));
      expect(r.requests, isEmpty);
    });

    test('not configured: unavailable and refused', () async {
      final r = _repo((_) async => fail('no request expected'));
      expect(r.auth.canUseGoogle, isFalse);
      expect(
        (await r.auth.signInWithGoogle()).failureOrNull,
        isA<ForbiddenFailure>(),
      );
    });
  });

  group('deleteAccount', () {
    Future<SupabaseAuthRepository> signedIn(
      _Handler functions, {
      _FakeGoogle? google,
    }) async {
      final r = _repo((request) async {
        if (request.url.path.startsWith('/functions/')) {
          return await functions(request);
        }
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('', 204);
        }
        return _json(200, _session());
      }, google: google);
      await r.auth.verifyPhoneCode(_phone, '123456');
      return r.auth;
    }

    test('calls the function, then signs out on this phone', () async {
      final google = _FakeGoogle('t');
      String? authHeader;
      final auth = await signedIn((request) async {
        authHeader = request.headers['authorization'];
        return _json(200, {'deleted': true});
      }, google: google);
      expect(
        await auth.deleteAccount(),
        const Success(DeletionOutcome.deleted),
      );
      expect(authHeader, 'Bearer header.payload.signature');
      expect(auth.currentUser, isNull);
      expect(google.signOuts, 1);
    });

    test(
      'an old sign-in asks to sign in again, and keeps the session',
      () async {
        final auth = await signedIn(
          (_) async => _json(403, {'error': 'reauth_required'}),
        );
        expect(
          await auth.deleteAccount(),
          const Success(DeletionOutcome.reauthRequired),
        );
        expect(auth.currentUser, isNotNull);
      },
    );

    test('server errors are failures, and keep the session', () async {
      final auth = await signedIn(
        (_) async => _json(500, {'error': 'delete_failed'}),
      );
      expect(
        (await auth.deleteAccount()).failureOrNull,
        isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
      );
      expect(auth.currentUser, isNotNull);
      final unauthorized = await signedIn(
        (_) async => _json(401, {'error': 'unauthorized'}),
      );
      expect(
        (await unauthorized.deleteAccount()).failureOrNull,
        isA<UnauthorizedFailure>(),
      );
    });
  });
}
