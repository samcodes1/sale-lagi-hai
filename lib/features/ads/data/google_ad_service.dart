import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';

/// [AdService] over Google AdMob and its consent platform (UMP).
final class GoogleAdService implements AdService {
  new({
    required this.bannerUnitId,
    required this.interstitialUnitId,
    required AppLogger logger,
  }) : _logger = logger;

  final String bannerUnitId;
  final String interstitialUnitId;
  final AppLogger _logger;

  /// The next full-screen ad, loaded ahead so it shows without a wait.
  InterstitialAd? _interstitial;

  @override
  bool get enabled => true;

  @override
  Future<bool> start() async {
    try {
      await _updateConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      unawaited(_loadInterstitial());
      return true;
    } on Object catch (error) {
      _logger.warning('Ads could not start', error: error);
      return false;
    }
  }

  /// Shows the consent form if this shopper's region requires one. On
  /// failure, `canRequestAds` still answers from the last consent given.
  Future<void> _updateConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => unawaited(
        ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete()),
      ),
      (_) => done.complete(),
    );
    return done.future;
  }

  @override
  Future<LoadedBanner?> loadBanner(
    AdBannerSize size, {
    required int width,
  }) async {
    if (bannerUnitId.isEmpty) return null;
    final done = Completer<LoadedBanner?>();
    try {
      final AdSize adSize = switch (size) {
        AdBannerSize.rectangle => AdSize.mediumRectangle,
        AdBannerSize.strip =>
          await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
                Orientation.portrait,
                width,
              ) ??
              AdSize.banner,
      };
      final ad = BannerAd(
        size: adSize,
        adUnitId: bannerUnitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) => done.complete(_GoogleBanner(ad as BannerAd)),
          onAdFailedToLoad: (ad, _) {
            unawaited(ad.dispose());
            done.complete(null);
          },
        ),
      );
      unawaited(ad.load());
    } on Object catch (error) {
      _logger.warning('Banner could not load', error: error);
      if (!done.isCompleted) done.complete(null);
    }
    return done.future;
  }

  Future<void> _loadInterstitial() async {
    if (interstitialUnitId.isEmpty) return;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );
    } on Object catch (error) {
      _logger.warning('Interstitial could not load', error: error);
    }
  }

  void _finished(InterstitialAd ad) {
    unawaited(ad.dispose());
    unawaited(_loadInterstitial());
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: _finished,
      onAdFailedToShowFullScreenContent: (ad, _) => _finished(ad),
    );
    try {
      await ad.show();
      return true;
    } on Object catch (error) {
      _logger.warning('Interstitial could not show', error: error);
      return false;
    }
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } on Object catch (error) {
      _logger.warning('Ad privacy options unknown', error: error);
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } on Object catch (error) {
      _logger.warning('Ad privacy options could not show', error: error);
    }
  }
}

final class _GoogleBanner implements LoadedBanner {
  const new(this._ad);

  final BannerAd _ad;

  @override
  double get width => _ad.size.width.toDouble();

  @override
  double get height => _ad.size.height.toDouble();

  @override
  Widget get view => AdWidget(ad: _ad);

  @override
  void dispose() => unawaited(_ad.dispose());
}
