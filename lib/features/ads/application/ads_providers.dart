import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
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

/// Full-screen ads at natural breaks, paced by [InterstitialPacing].
final interstitialsProvider = Provider<Interstitials>(
  (ref) => Interstitials(
    ref.watch(adServiceProvider),
    InterstitialPacing(clock: ref.watch(clockProvider)),
  ),
);

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
