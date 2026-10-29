import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/result/result.dart';

enum SignInMethod { phone, google }

/// The signed-in shopper. Personal data: never log it.
@immutable
final class AppUser {
  const new({required this.id, required this.method, this.phone, this.email});

  final String id;
  final SignInMethod method;

  /// E.164 (`+923001234567`), for phone sign-ins.
  final String? phone;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.method == method &&
      other.phone == phone &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, method, phone, email);

  @override
  String toString() => 'AppUser(${method.name})';
}

enum DeletionOutcome {
  deleted,

  /// The last sign-in is too old: sign in again (a fresh code, or Google)
  /// and retry. Protects against a stolen or left-open session.
  reauthRequired,
}

/// Sign-in is optional (the app is guest-first): phone number with a
/// one-time code, or Google. Failures are `AppFailure`s; a wrong or
/// expired code is a `ValidationFailure` with `{'code': 'invalid'}`, a bad
/// number `{'phone': 'invalid'}`.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// The user now and on every change (sign-in, sign-out, deletion).
  Stream<AppUser?> userChanges();

  /// Whether Google sign-in is configured for this build and platform.
  bool get canUseGoogle;

  Future<Result<void>> sendPhoneCode(String e164);

  Future<Result<AppUser>> verifyPhoneCode(String e164, String code);

  /// `null` when the shopper closed the Google sheet.
  Future<Result<AppUser?>> signInWithGoogle();

  /// Signs out on this phone only.
  Future<Result<void>> signOut();

  /// Deletes the account and everything in it on the server, then signs
  /// out. Local data is the caller's to clear.
  Future<Result<DeletionOutcome>> deleteAccount();
}
