import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/domain/ad_settings.dart';
import 'package:sale_lagi_hai/features/ads/domain/app_open_pacing.dart';
import 'package:sale_lagi_hai/features/ads/domain/interstitial_pacing.dart';

/// The ad network. Overridden in `bootstrap` when this build has ads.
final adServiceProvider = Provider<AdService>((ref) => const NoAdService());

/// Consent and start-up, once, after onboarding (the shell asks for it).
/// Whether ads may be requested.
final adsStartupProvider = FutureProvider<bool>(
  (ref) => ref.watch(adServiceProvider).start(),
);

/// Whether Settings, Privacy needs its "Ad choices" row.
final adPrivacyOptionsProvider = FutureProvider<bool>((ref) async {
  await ref.watch(adsStartupProvider.future);
  return await ref.watch(adServiceProvider).privacyOptionsRequired();
});

/// Staff's ad settings, read once per launch. Any failure means the
/// defaults: settings must never stop the app, or its ads.
final adSettingsProvider = FutureProvider<AdSettings>(
  (ref) async {
    if (!ref.watch(adServiceProvider).enabled) return const AdSettings();
    try {
      final rows = await ref
          .watch(backendGatewayProvider)
          .select(const TableQuery('ad_settings', limit: 1));
      return rows.isEmpty ? const AdSettings() : AdSettings.fromMap(rows.first);
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Ad settings could not load', error: error);
      return const AdSettings();
    }
  },
  retry: (_, _) => null,
);

/// The settings now: the defaults until staff's have loaded.
final currentAdSettingsProvider = Provider<AdSettings>(
  (ref) => ref.watch(adSettingsProvider).value ?? const AdSettings(),
);

/// Full-screen ads at natural breaks, paced by [InterstitialPacing].
final interstitialsProvider = Provider<Interstitials>((ref) {
  final settings = ref.watch(currentAdSettingsProvider);
  return Interstitials(
    ref.watch(adServiceProvider),
    InterstitialPacing(
      clock: ref.watch(clockProvider),
      breaksPerAd: settings.interstitialBreaks,
      minGap: settings.interstitialGap,
      maxPerSession: settings.enabled ? settings.interstitialMaxPerSession : 0,
    ),
  );
});

class Interstitials {
  const new(this._service, this._pacing);

  final AdService _service;
  final InterstitialPacing _pacing;

  /// The shopper has just finished with a page.
  void onBreak() {
    if (_service.enabled && _pacing.onBreak()) unawaited(_show());
  }

  Future<void> _show() async {
    if (await _service.showInterstitial()) _pacing.markShown();
  }
}

/// Which launch of the app this is, counting from 1. Counted once per run.
final appLaunchCountProvider = FutureProvider<int>((ref) async {
  const key = 'ads.launches';
  final store = ref.watch(keyValueStoreProvider);
  try {
    final launches = (int.tryParse(await store.getString(key) ?? '') ?? 0) + 1;
    await store.setString(key, '$launches');
    return launches;
  } on Object catch (error) {
    ref.read(loggerProvider).warning('Launch count unknown', error: error);
    // Unknown counts as new: no app open ads for this run.
    return 0;
  }
});

/// App open ads as the shopper comes back to the app, paced by
/// [AppOpenPacing]. Nothing shows until the launch count is known.
final appOpenAdsProvider = Provider<AppOpenAds>((ref) {
  final service = ref.watch(adServiceProvider);
  final settings = ref.watch(currentAdSettingsProvider);
  final active =
      service.enabled && settings.enabled && settings.appOpenEnabled;
  return AppOpenAds(
    service,
    AppOpenPacing(
      clock: ref.watch(clockProvider),
      launches: active ? ref.watch(appLaunchCountProvider).value ?? 0 : 0,
      minLaunches: settings.appOpenMinLaunches,
      minGap: settings.appOpenGap,
    ),
  );
});

class AppOpenAds {
  const new(this._service, this._pacing);

  final AdService _service;
  final AppOpenPacing _pacing;

  /// The app went to the background.
  void onLeft() => _pacing.onLeft();

  /// The app is back in front.
  void onReturned() {
    if (!_service.enabled) return;
    final fromAd = _service.takeAdActivity();
    if (_pacing.onReturned(fromAd: fromAd)) unawaited(_show());
  }

  Future<void> _show() async {
    if (await _service.showAppOpen()) _pacing.markShown();
  }
}
