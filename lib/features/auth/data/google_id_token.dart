import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Gets a Google ID token for Supabase to verify. Behind an interface so
/// tests and builds without Google don't touch the plugin.
abstract interface class GoogleIdTokenSource {
  /// The ID token, or `null` when the shopper closed the Google sheet.
  Future<String?> idToken();

  Future<void> signOut();
}

/// Native Google sign-in (Credential Manager on Android). The ID token is
/// issued for [serverClientId], the web client ID Supabase is configured
/// with. Not on the web: there it needs Google's own button.
final class PluginGoogleIdTokenSource implements GoogleIdTokenSource {
  new(this.serverClientId);

  final String serverClientId;
  Future<void>? _initialized;

  static bool get supported => !kIsWeb;

  @override
  Future<String?> idToken() async {
    final google = GoogleSignIn.instance;
    await (_initialized ??= google.initialize(serverClientId: serverClientId));
    try {
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialized == null) return;
    await GoogleSignIn.instance.signOut();
  }
}
