import 'package:flutter/widgets.dart';

/// The two banner shapes the app uses: a strip as wide as the screen, and
/// a 300 x 250 rectangle (Google's best-paying size) between content.
enum AdBannerSize { strip, rectangle }

/// A banner that has loaded and can be shown.
abstract interface class LoadedBanner {
  double get width;
  double get height;
  Widget get view;
  void dispose();
}

/// The app's only door to the ad network, so the rest of the app can run
/// without it: on the web, in tests, and in builds with no ad unit IDs.
/// Implementations never throw: with no ad to show, there is simply no ad.
abstract interface class AdService {
  /// Whether this build can show ads at all.
  bool get enabled;

  /// Asks for consent where the law requires it, then starts the ad network.
  /// Returns whether ads may be requested.
  Future<bool> start();

  /// A banner [width] logical pixels wide at most, or `null` if none filled.
  Future<LoadedBanner?> loadBanner(AdBannerSize size, {required int width});

  /// Shows a full-screen ad if one is ready; says whether it did.
  Future<bool> showInterstitial();

  /// Whether Settings must offer a way to change ad consent.
  Future<bool> privacyOptionsRequired();

  /// Shows the ad consent form again.
  Future<void> showPrivacyOptions();
}

/// No ads: the default, and every build without ad unit IDs.
class NoAdService implements AdService {
  const new();

  @override
  bool get enabled => false;

  @override
  Future<bool> start() async => false;

  @override
  Future<LoadedBanner?> loadBanner(
    AdBannerSize size, {
    required int width,
  }) async => null;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
