/// Decides when an app open ad may show as the shopper comes back to the
/// app. Following Google's guidance, never:
/// - in a new shopper's first launches;
/// - after a short trip away (a share sheet, a permission, a quick look
///   at another app);
/// - when they are coming back from an ad (a click or a full-screen ad);
/// - more often than [minGap].
final class AppOpenPacing {
  new({
    required this._clock,
    required this.launches,
    this.minLaunches = 2,
    this.minAway = const Duration(minutes: 1),
    this.minGap = const Duration(hours: 1),
  });

  final DateTime Function() _clock;

  /// Which launch of the app this is, counting from 1.
  final int launches;

  final int minLaunches;

  /// How long the shopper must have been away.
  final Duration minAway;

  /// The least time between app open ads.
  final Duration minGap;

  DateTime? _leftAt;
  DateTime? _lastShown;

  /// The app went to the background.
  void onLeft() => _leftAt ??= _clock();

  /// The app is back in front. Says whether an ad may show now.
  bool onReturned({required bool fromAd}) {
    final leftAt = _leftAt;
    _leftAt = null;
    if (fromAd || leftAt == null || launches < minLaunches) return false;
    final now = _clock();
    if (now.difference(leftAt) < minAway) return false;
    final last = _lastShown;
    return last == null || now.difference(last) >= minGap;
  }

  /// Starts the next wait, after an ad really showed.
  void markShown() => _lastShown = _clock();
}
