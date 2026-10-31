import 'dart:io' show Platform;

import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/data/google_ad_service.dart';

/// Google's ads on Android when this build has ad unit IDs, else none.
AdService createAdService(AppConfig config, AppLogger logger) {
  if (!config.hasAds || !Platform.isAndroid) return const NoAdService();
  return GoogleAdService(
    bannerUnitId: config.adBannerUnitId,
    interstitialUnitId: config.adInterstitialUnitId,
    logger: logger,
  );
}
