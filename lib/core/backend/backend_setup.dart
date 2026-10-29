import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/backend/secure_session_storage.dart';
import 'package:sale_lagi_hai/core/backend/supabase_gateway.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The backend this build talks to. Overridden in `bootstrap()`.
final backendGatewayProvider = Provider<BackendGateway>(
  (ref) => throw UnimplementedError(
    'backendGatewayProvider must be overridden in bootstrap().',
  ),
);

/// Whether the app runs on demo data (no backend configured: dev only).
final demoModeProvider = Provider<bool>((ref) => false);

/// Connects to Supabase when the build has a backend; otherwise (dev
/// builds without one) returns the in-memory demo backend.
///
/// The session and PKCE verifier are kept in secure storage, not the SDK's
/// default SharedPreferences. The SDK's own deep-link handling is off:
/// links go through one validating service (Phase 5.3).
Future<BackendGateway> createBackend(
  AppConfig config,
  SecureStore secureStore,
) async {
  if (!config.hasBackend) return DemoGateway();
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(secureStore),
      pkceAsyncStorage: SecurePkceStorage(secureStore),
      detectSessionInUri: false,
    ),
  );
  return SupabaseGateway(supabase.client);
}
