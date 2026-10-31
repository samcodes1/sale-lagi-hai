import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';

/// No ads on this platform.
AdService createAdService(AppConfig config, AppLogger logger) =>
    const NoAdService();
