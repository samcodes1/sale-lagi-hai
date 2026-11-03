import 'package:flutter/widgets.dart';

/// The ad slots the app uses: a strip as wide as the screen, a 300 x 250
/// rectangle (Google's best-paying banner) between content, and a native
/// ad styled like the app, which falls back to a rectangle when none fills.
enum AdBannerSize { strip, rectangle, native }

/// The app's colours for a native ad, so it sits in the page like a card.
final class NativeAdColors {
  const new({
    required this.background,
    required this.text,
    required this.mutedText,
    required this.action,
    required this.onAction,
  });

  final Color background;
  final Color text;
  final Color mutedText;
  final Color action;
  final Color onAction;
}

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

  /// A native ad [width] logical pixels wide at most, or `null` if none
  /// filled.
  Future<LoadedBanner?> loadNative(NativeAdColors colors, {required int width});

  /// Shows a full-screen ad if one is ready; says whether it did.
  Future<bool> showInterstitial();

  /// Shows an app open ad if one is ready; says whether it did.
  Future<bool> showAppOpen();

  /// Whether the shopper left the app for an ad (clicked one, or saw a
  /// full-screen one) since this was last asked.
  bool takeAdActivity();

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
  Future<LoadedBanner?> loadNative(
    NativeAdColors colors, {
    required int width,
  }) async => null;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showAppOpen() async => false;

  @override
  bool takeAdActivity() => false;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
