import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/data/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AppConfig _config({String google = ''}) => AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH',
  supabaseUrl: '',
  supabasePublishableKey: '',
  googleServerClientId: google,
);

void main() {
  final logger = AppLogger(sinks: []);
  const googleId = '1234567890-abc.apps.googleusercontent.com';

  test('no backend: the demo sign-in, with Google only when configured', () {
    final plain = createAuthRepository(_config(), null, logger);
    expect(plain, isA<DemoAuthRepository>());
    expect(plain.canUseGoogle, isFalse);
    expect(
      createAuthRepository(
        _config(google: googleId),
        null,
        logger,
      ).canUseGoogle,
      isTrue,
    );
  });

  test('a backend: Supabase Auth, with Google only when configured', () {
    final client = SupabaseClient('https://p.supabase.co', 'sb_publishable_x');
    addTearDown(client.dispose);
    final plain = createAuthRepository(_config(), client, logger);
    expect(plain, isA<SupabaseAuthRepository>());
    expect(plain.canUseGoogle, isFalse);
    expect(
      createAuthRepository(
        _config(google: googleId),
        client,
        logger,
      ).canUseGoogle,
      isTrue,
    );
  });
}
