// QA (sub-phase 4.2 gate): session tests. The real supabase_flutter
// start-up path (`Supabase.initialize` with the app's SecureSessionStorage,
// as `createBackend` wires it) over mocked HTTP: is the session kept in
// secure storage, restored across restarts, kept while offline, dropped
// when the server revokes it, and removed on sign-out and deletion? And
// does `SupabaseAuthRepository.userChanges` follow along?
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sale_lagi_hai/core/backend/secure_session_storage.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:sale_lagi_hai/features/auth/data/supabase_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

const _uid = '7a1c2f3e-0000-4000-8000-000000000001';
const _phone = '+923001234567';

String _b64(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _accessToken(DateTime expires) {
  final exp = expires.millisecondsSinceEpoch ~/ 1000;
  final header = _b64({'alg': 'ES256', 'typ': 'JWT'});
  final claims = _b64({'sub': _uid, 'role': 'authenticated', 'exp': exp});
  return '$header.$claims.c2lnbmF0dXJl';
}

Map<String, Object?> _sessionJson(DateTime expires) => {
  'access_token': _accessToken(expires),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': expires.millisecondsSinceEpoch ~/ 1000,
  'refresh_token': 'refresh-1',
  'user': {
    'id': _uid,
    'aud': 'authenticated',
    'role': 'authenticated',
    'phone': '923001234567',
    'app_metadata': {'provider': 'phone'},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-10-29T12:00:00Z',
  },
};

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

typedef _Handler = Future<http.Response> Function(http.Request request);

/// One app launch: Supabase as `createBackend` sets it up, over [store].
Future<SupabaseAuthRepository> _launch(
  InMemorySecureStore store,
  _Handler handler,
) async {
  await Supabase.initialize(
    url: 'https://p.supabase.co',
    publishableKey: 'sb_publishable_test',
    httpClient: MockClient(handler),
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(store),
      pkceAsyncStorage: SecurePkceStorage(store),
      detectSessionInUri: false,
    ),
  );
  // Let initialization's own async work (recovery, persistence) settle.
  await _settle();
  return SupabaseAuthRepository(Supabase.instance.client, AppLogger(sinks: []));
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _quit() => Supabase.instance.dispose();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async {
    try {
      await _quit();
    } on Object {
      // not initialised in this test
    }
  });

  final future = DateTime.now().add(const Duration(hours: 1));
  final past = DateTime.now().subtract(const Duration(hours: 2));

  test('a first launch is a guest, and the stream starts with null', () async {
    final auth = await _launch(
      InMemorySecureStore(),
      (_) async => fail('no request expected'),
    );
    expect(auth.currentUser, isNull);
    expect(await auth.userChanges().first, isNull);
  });

  test('a sign-in is kept in secure storage and survives a restart', () async {
    final store = InMemorySecureStore();
    var auth = await _launch(store, (request) async {
      if (request.url.path == '/auth/v1/verify') {
        return _json(200, _sessionJson(future));
      }
      return fail('unexpected ${request.url.path}');
    });
    await auth.verifyPhoneCode(_phone, '123456');
    await _settle();
    final stored = store.values[SecureKey.authSession];
    expect(stored, isNotNull, reason: 'the session is persisted');
    expect(stored, contains('refresh-1'));

    await _quit();
    auth = await _launch(store, (_) async => fail('no request expected'));
    expect(auth.currentUser?.id, _uid);
    expect(auth.currentUser?.phone, _phone);
    expect((await auth.userChanges().first)?.id, _uid);
  });

  test('an expired session at launch while offline stays signed in', () async {
    final store = InMemorySecureStore()
      ..values[SecureKey.authSession] = jsonEncode(_sessionJson(past));
    final auth = await _launch(
      store,
      (_) async => throw http.ClientException('offline'),
    );
    expect(auth.currentUser?.id, _uid, reason: 'offline is not a sign-out');
    expect(store.values[SecureKey.authSession], isNotNull);
  });

  test(
    'an expired session the server no longer knows signs out at launch',
    () async {
      final store = InMemorySecureStore()
        ..values[SecureKey.authSession] = jsonEncode(_sessionJson(past));
      final auth = await _launch(store, (request) async {
        if (request.url.path == '/auth/v1/token') {
          return _json(400, {
            'code': 'refresh_token_not_found',
            'msg': 'Invalid Refresh Token: Refresh Token Not Found',
          });
        }
        return fail('unexpected ${request.url.path}');
      });
      final events = <AppUser?>[];
      final errors = <Object>[];
      final sub = auth.userChanges().listen(events.add, onError: errors.add);
      await _settle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _settle();
      expect(auth.currentUser, isNull);
      expect(store.values[SecureKey.authSession], isNull);
      expect(events.last, isNull, reason: 'listeners hear about it');
      await sub.cancel();
    },
  );

  test('signing out removes the stored session', () async {
    final store = InMemorySecureStore()
      ..values[SecureKey.authSession] = jsonEncode(_sessionJson(future));
    final auth = await _launch(store, (request) async {
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      return fail('unexpected ${request.url.path}');
    });
    expect(auth.currentUser, isNotNull);
    final events = <AppUser?>[];
    final sub = auth.userChanges().listen(events.add);
    expect((await auth.signOut()).isSuccess, isTrue);
    await _settle();
    expect(store.values[SecureKey.authSession], isNull);
    expect(events.last, isNull);
    await sub.cancel();
  });

  test('deleting the account removes the stored session', () async {
    final store = InMemorySecureStore()
      ..values[SecureKey.authSession] = jsonEncode(_sessionJson(future));
    final auth = await _launch(store, (request) async {
      if (request.url.path == '/functions/v1/delete-account') {
        return _json(200, {'deleted': true});
      }
      // The user is gone: Auth answers 403 user_not_found to /logout.
      if (request.url.path == '/auth/v1/logout') {
        return _json(403, {'code': 'user_not_found', 'msg': 'User not found'});
      }
      return fail('unexpected ${request.url.path}');
    });
    expect(await auth.deleteAccount(), const Success(DeletionOutcome.deleted));
    await _settle();
    expect(auth.currentUser, isNull);
    expect(store.values[SecureKey.authSession], isNull);
  });

  // QA BUG 4.2-A4 (S3): the server deleted the account, but the /logout
  // call that follows fails on a network blip, and deleteAccount() reports
  // a failure: the delete page shows an error, keeps this phone's data and
  // never returns to onboarding (supabase_auth_repository.dart:252).
  test('QA BUG 4.2-A4: a deleted account is reported deleted even if /logout '
      'fails offline', () async {
    final store = InMemorySecureStore()
      ..values[SecureKey.authSession] = jsonEncode(_sessionJson(future));
    final auth = await _launch(store, (request) async {
      if (request.url.path == '/functions/v1/delete-account') {
        return _json(200, {'deleted': true});
      }
      throw http.ClientException('connection reset');
    });
    expect(await auth.deleteAccount(), const Success(DeletionOutcome.deleted));
    expect(auth.currentUser, isNull);
  });

  test('the userChanges stream survives an auth error event', () async {
    final store = InMemorySecureStore()
      ..values[SecureKey.authSession] = jsonEncode(_sessionJson(future));
    final auth = await _launch(store, (request) async {
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      return fail('unexpected ${request.url.path}');
    });
    final events = <AppUser?>[];
    final errors = <Object>[];
    final done = Completer<void>();
    final sub = auth.userChanges().listen(
      events.add,
      onError: errors.add,
      onDone: done.complete,
    );
    await _settle();
    // What GoTrue does when a background refresh fails.
    // ignore: invalid_use_of_internal_member
    Supabase.instance.client.auth.notifyException(
      const AuthException('refresh failed'),
    );
    await _settle();
    await auth.signOut();
    await _settle();
    expect(errors, hasLength(1));
    expect(events.last, isNull, reason: 'events after an error still arrive');
    expect(done.isCompleted, isFalse);
    await sub.cancel();
  });
}
