import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/data/google_id_token.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [AuthRepository] over Supabase Auth. The session lives in secure
/// storage (see `createBackend`).
final class SupabaseAuthRepository implements AuthRepository {
  new(this._client, this._logger, {this._google});

  final SupabaseClient _client;
  final AppLogger _logger;
  final GoogleIdTokenSource? _google;

  GoTrueClient get _auth => _client.auth;

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final provider = user.appMetadata['provider'];
    final phone = user.phone;
    return AppUser(
      id: user.id,
      method: provider == 'google' ? SignInMethod.google : SignInMethod.phone,
      // Supabase stores phones without the "+".
      phone: phone == null || phone.isEmpty
          ? null
          : (phone.startsWith('+') ? phone : '+$phone'),
      email: user.email == null || user.email!.isEmpty ? null : user.email,
    );
  }

  /// Auth errors about the input, not the network: a wrong or expired code,
  /// a number the SMS provider rejects.
  static ExceptionMapper _inputMapper(String field) =>
      (error, stackTrace) => switch (error) {
        AuthApiException(:final statusCode, :final code)
            when statusCode == '403' ||
                statusCode == '400' ||
                statusCode == '422' ||
                code == 'otp_expired' =>
          ValidationFailure(
            fieldErrors: {field: 'invalid'},
            cause: error,
            stackTrace: stackTrace,
          ),
        _ => null,
      };

  Future<Result<T>> _guard<T>(
    Future<T> Function() body, {
    String? inputField,
  }) => guard(
    body,
    logger: _logger,
    mappers: [
      if (inputField != null) _inputMapper(inputField),
      backendErrorMapper,
    ],
  );

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> userChanges() async* {
    yield currentUser;
    yield* _auth.onAuthStateChange.map((s) => _toAppUser(s.session?.user));
  }

  @override
  bool get canUseGoogle => _google != null;

  @override
  Future<Result<void>> sendPhoneCode(String e164) => _guard(
    () => _auth.signInWithOtp(phone: e164, shouldCreateUser: true),
    inputField: 'phone',
  );

  @override
  Future<Result<AppUser>> verifyPhoneCode(String e164, String code) =>
      _guard(() async {
        final response = await _auth.verifyOTP(
          type: OtpType.sms,
          phone: e164,
          token: code,
        );
        return _toAppUser(response.user) ?? (throw const UnauthorizedFailure());
      }, inputField: 'code');

  @override
  Future<Result<AppUser?>> signInWithGoogle() => _guard(() async {
    final google = _google;
    if (google == null) throw const ForbiddenFailure();
    final idToken = await google.idToken();
    if (idToken == null) return null;
    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    return _toAppUser(response.user) ?? (throw const UnauthorizedFailure());
  });

  @override
  Future<Result<void>> signOut() => _guard(() async {
    await _auth.signOut();
    await _google?.signOut();
  });

  @override
  Future<Result<DeletionOutcome>> deleteAccount() => _guard(() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 403 &&
          details is Map &&
          details['error'] == 'reauth_required') {
        return DeletionOutcome.reauthRequired;
      }
      if (e.status == 401) throw UnauthorizedFailure(cause: e);
      throw ServerFailure(statusCode: e.status, cause: e);
    }
    // The server session is gone with the user; clear the local one.
    await _auth.signOut();
    await _google?.signOut();
    return DeletionOutcome.deleted;
  });
}
