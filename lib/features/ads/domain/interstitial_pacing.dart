/// Decides when a full-screen ad may show. They appear only at natural
/// breaks (leaving a deal, brand or category page), and never often enough
/// to breach Google's disruptive-ads policy or drive shoppers away.
final class InterstitialPacing {
  new({
    required DateTime Function() clock,
    this.breaksPerAd = 3,
    this.minGap = const Duration(minutes: 2),
    this.maxPerSession = 8,
  }) : _clock = clock,
       _since = clock();

  final DateTime Function() _clock;

  /// How many breaks pass for each ad.
  final int breaksPerAd;

  /// The least time between ads, and before the first one.
  final Duration minGap;

  /// The most ads in one run of the app.
  final int maxPerSession;

  /// When the session started, then when the last ad showed.
  DateTime _since;
  var _breaks = 0;
  var _shown = 0;

  /// Counts a break, and says whether an ad may show at it.
  bool onBreak() {
    _breaks++;
    return _breaks >= breaksPerAd &&
        _shown < maxPerSession &&
        _clock().difference(_since) >= minGap;
  }

  /// Starts the next wait, after an ad really showed.
  void markShown() {
    _breaks = 0;
    _shown++;
    _since = _clock();
  }
}
