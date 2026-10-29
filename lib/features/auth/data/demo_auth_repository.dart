import 'dart:async';

import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';

/// Sign-in for builds without a backend (dev, tests, web QA). No SMS is
/// sent: the code is always [code]. It follows the real rules: 5 codes per
/// number an hour, codes expire after 10 minutes, and deleting the account
/// needs a sign-in in the last 5 minutes.
final class DemoAuthRepository implements AuthRepository {
  new({DateTime Function()? clock, this.googleAvailable = true})
    : _clock = clock ?? DateTime.now;

  static const code = '123456';
  static const _codesPerHour = 5;
  static const _codeLifetime = Duration(minutes: 10);
  static const _reauthWindow = Duration(minutes: 5);

  final DateTime Function() _clock;
  final bool googleAvailable;

  /// The account the Google sheet picks. Tests switch it to sign in as
  /// someone else.
  AppUser googleAccount = const AppUser(
    id: '00000000-0000-4000-9000-0000000000aa',
    method: SignInMethod.google,
    email: 'demo.shopper@example.com',
  );

  /// The ids of the accounts deleted so far.
  final deletedIds = <String>[];
  final _changes = StreamController<AppUser?>.broadcast();
  final _sent = <String, List<DateTime>>{};
  AppUser? _user;
  DateTime? _signedInAt;
  int _next = 1;

  String _serial() => (_next++).toString().padLeft(12, '0');

  void _signIn(AppUser user) {
    _user = user;
    _signedInAt = _clock();
    _changes.add(user);
  }

  @override
  AppUser? get currentUser => _user;

  // Listens to changes from the moment of subscription, so nothing
  // between the current value and the first change is missed.
  @override
  Stream<AppUser?> userChanges() => Stream.multi((controller) {
    controller.add(_user);
    final changes = _changes.stream.listen(controller.add);
    controller.onCancel = changes.cancel;
  });

  @override
  bool get canUseGoogle => googleAvailable;

  @override
  Future<Result<void>> sendPhoneCode(String e164) async {
    final now = _clock();
    final recent = [
      for (final at in _sent[e164] ?? const <DateTime>[])
        if (now.difference(at) < const Duration(hours: 1)) at,
    ];
    if (recent.length >= _codesPerHour) {
      return Failure(
        RateLimitedFailure(
          retryAfter: const Duration(hours: 1) - now.difference(recent.first),
        ),
      );
    }
    _sent[e164] = [...recent, now];
    return const Success(null);
  }

  @override
  Future<Result<AppUser>> verifyPhoneCode(String e164, String code) async {
    final sent = _sent[e164];
    final fresh =
        sent != null &&
        sent.isNotEmpty &&
        _clock().difference(sent.last) < _codeLifetime;
    if (!fresh || code != DemoAuthRepository.code) {
      return const Failure(ValidationFailure(fieldErrors: {'code': 'invalid'}));
    }
    final user = _user?.phone == e164
        ? _user!
        : AppUser(
            id: '00000000-0000-4000-9000-${_serial()}',
            method: SignInMethod.phone,
            phone: e164,
          );
    _signIn(user);
    return Success(user);
  }

  @override
  Future<Result<AppUser?>> signInWithGoogle() async {
    if (!googleAvailable) return const Failure(ForbiddenFailure());
    final user = googleAccount;
    _signIn(user);
    return Success(user);
  }

  @override
  Future<Result<void>> signOut() async {
    _user = null;
    _signedInAt = null;
    _changes.add(null);
    return const Success(null);
  }

  @override
  Future<Result<DeletionOutcome>> deleteAccount() async {
    final signedInAt = _signedInAt;
    if (_user == null || signedInAt == null) {
      return const Failure(UnauthorizedFailure());
    }
    if (_clock().difference(signedInAt) > _reauthWindow) {
      return const Success(DeletionOutcome.reauthRequired);
    }
    deletedIds.add(_user!.id);
    await signOut();
    return const Success(DeletionOutcome.deleted);
  }
}
