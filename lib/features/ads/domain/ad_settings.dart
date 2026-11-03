/// How hard the app pushes ads, set by staff in the `ad_settings` row so
/// it can be tuned without a release.
///
/// Every value is held to policy-safe bounds here as well as in the
/// database: a bad row may show fewer ads, never more than Google allows.
final class AdSettings {
  const new({
    this.enabled = true,
    this.nativeEnabled = true,
    this.feedAdEvery = 6,
    this.interstitialBreaks = 3,
    this.interstitialGap = const Duration(minutes: 2),
    this.interstitialMaxPerSession = 8,
    this.appOpenEnabled = true,
    this.appOpenMinLaunches = 2,
    this.appOpenGap = const Duration(hours: 1),
  });

  /// Reads the row, falling back to the default for anything missing or of
  /// the wrong type, and clamping the rest.
  factory fromMap(Map<String, Object?> row) {
    const d = AdSettings();
    bool flag(String key, bool fallback) => switch (row[key]) {
      final bool value => value,
      _ => fallback,
    };
    int number(String key, int fallback, int min, int max) =>
        switch (row[key]) {
          final num value => value.toInt().clamp(min, max),
          _ => fallback,
        };
    return AdSettings(
      enabled: flag('enabled', d.enabled),
      nativeEnabled: flag('native_enabled', d.nativeEnabled),
      feedAdEvery: number('feed_ad_every', d.feedAdEvery, 4, 30),
      interstitialBreaks: number(
        'interstitial_breaks',
        d.interstitialBreaks,
        2,
        20,
      ),
      interstitialGap: Duration(
        seconds: number(
          'interstitial_gap_seconds',
          d.interstitialGap.inSeconds,
          60,
          3600,
        ),
      ),
      interstitialMaxPerSession: number(
        'interstitial_max_per_session',
        d.interstitialMaxPerSession,
        0,
        12,
      ),
      appOpenEnabled: flag('app_open_enabled', d.appOpenEnabled),
      appOpenMinLaunches: number(
        'app_open_min_launches',
        d.appOpenMinLaunches,
        1,
        20,
      ),
      appOpenGap: Duration(
        minutes: number(
          'app_open_gap_minutes',
          d.appOpenGap.inMinutes,
          30,
          1440,
        ),
      ),
    );
  }

  /// The kill switch: off, the app shows no ads at all.
  final bool enabled;

  /// Off, the native slots in the deal lists show a rectangle banner.
  final bool nativeEnabled;

  /// An ad follows every this many deals in a list.
  final int feedAdEvery;

  /// How many breaks (leaving a page) pass for each full-screen ad.
  final int interstitialBreaks;

  /// The least time between full-screen ads, and before the first.
  final Duration interstitialGap;

  /// The most full-screen ads in one run of the app; 0 turns them off.
  final int interstitialMaxPerSession;

  final bool appOpenEnabled;

  /// App open ads start on this launch of the app, so a new shopper's
  /// first visits are free of them.
  final int appOpenMinLaunches;

  /// The least time between app open ads.
  final Duration appOpenGap;
}
