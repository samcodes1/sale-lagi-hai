import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';

/// [AdService] over Google AdMob and its consent platform (UMP).
final class GoogleAdService implements AdService {
  new({
    required this.bannerUnitId,
    required this.interstitialUnitId,
    required this._logger,
    this.appOpenUnitId = '',
    this.nativeUnitId = '',
  });

  final String bannerUnitId;
  final String interstitialUnitId;
  final String appOpenUnitId;
  final String nativeUnitId;
  final AppLogger _logger;

  /// Google drops app open ads loaded more than four hours ago.
  static const _appOpenLifetime = Duration(hours: 4);

  /// How tall a medium native template is drawn.
  static const _nativeHeight = 360.0;

  /// The next full-screen ad, loaded ahead so it shows without a wait.
  InterstitialAd? _interstitial;

  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  var _appOpenShowing = false;

  var _adActivity = false;

  void _markActivity([Object? _]) => _adActivity = true;

  @override
  bool get enabled => true;

  @override
  Future<bool> start() async {
    try {
      await _updateConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      unawaited(_loadInterstitial());
      unawaited(_loadAppOpen());
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
      final adSize = switch (size) {
        AdBannerSize.rectangle || AdBannerSize.native =>
          AdSize.mediumRectangle,
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
          onAdLoaded: (ad) {
            final banner = ad as BannerAd;
            done.complete(
              _GoogleAdView(
                banner,
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
              ),
            );
          },
          onAdFailedToLoad: (ad, _) {
            unawaited(ad.dispose());
            done.complete(null);
          },
          onAdClicked: _markActivity,
        ),
      );
      unawaited(ad.load());
    } on Object catch (error) {
      _logger.warning('Banner could not load', error: error);
      if (!done.isCompleted) done.complete(null);
    }
    return await done.future;
  }

  @override
  Future<LoadedBanner?> loadNative(
    NativeAdColors colors, {
    required int width,
  }) async {
    if (nativeUnitId.isEmpty) return null;
    final done = Completer<LoadedBanner?>();
    final viewWidth = math.min(width, 400).toDouble();
    try {
      final ad = NativeAd(
        adUnitId: nativeUnitId,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: colors.background,
          cornerRadius: 16,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: colors.onAction,
            backgroundColor: colors.action,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.text,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.mutedText,
            size: 14,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.mutedText,
            size: 14,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) => done.complete(
            _GoogleAdView(
              ad as NativeAd,
              width: viewWidth,
              height: _nativeHeight,
            ),
          ),
          onAdFailedToLoad: (ad, _) {
            unawaited(ad.dispose());
            done.complete(null);
          },
          onAdClicked: _markActivity,
        ),
      );
      unawaited(ad.load());
    } on Object catch (error) {
      _logger.warning('Native ad could not load', error: error);
      if (!done.isCompleted) done.complete(null);
    }
    return await done.future;
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
      onAdShowedFullScreenContent: _markActivity,
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

  Future<void> _loadAppOpen() async {
    if (appOpenUnitId.isEmpty) return;
    try {
      await AppOpenAd.load(
        adUnitId: appOpenUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpen = ad;
            _appOpenLoadedAt = DateTime.now();
          },
          onAdFailedToLoad: (_) => _appOpen = null,
        ),
      );
    } on Object catch (error) {
      _logger.warning('App open ad could not load', error: error);
    }
  }

  void _appOpenFinished(AppOpenAd ad) {
    _appOpenShowing = false;
    unawaited(ad.dispose());
    unawaited(_loadAppOpen());
  }

  @override
  Future<bool> showAppOpen() async {
    if (_appOpenShowing) return false;
    final ad = _appOpen;
    final loadedAt = _appOpenLoadedAt;
    if (ad == null ||
        loadedAt == null ||
        DateTime.now().difference(loadedAt) >= _appOpenLifetime) {
      _appOpen = null;
      unawaited(ad?.dispose());
      unawaited(_loadAppOpen());
      return false;
    }
    _appOpen = null;
    _appOpenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: _markActivity,
      onAdDismissedFullScreenContent: _appOpenFinished,
      onAdFailedToShowFullScreenContent: (ad, _) => _appOpenFinished(ad),
    );
    try {
      await ad.show();
      return true;
    } on Object catch (error) {
      _logger.warning('App open ad could not show', error: error);
      _appOpenFinished(ad);
      return false;
    }
  }

  @override
  bool takeAdActivity() {
    final activity = _adActivity;
    _adActivity = false;
    return activity;
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

/// A loaded banner or native ad.
final class _GoogleAdView implements LoadedBanner {
  const new(this._ad, {required this.width, required this.height});

  final AdWithView _ad;

  @override
  final double width;

  @override
  final double height;

  @override
  Widget get view => AdWidget(ad: _ad);

  @override
  void dispose() => unawaited(_ad.dispose());
}
