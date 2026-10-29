import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';

/// The validated config for this build. Overridden once in `bootstrap`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap().',
  ),
);
