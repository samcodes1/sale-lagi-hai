import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';

/// Tells [AppOpenAds] when the app goes to the background and comes back.
/// It wraps the shell only, so nothing shows before onboarding is over.
class AppOpenAdGate extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppOpenAdGate> createState() => _AppOpenAdGateState();
}

class _AppOpenAdGateState extends ConsumerState<AppOpenAdGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(appOpenAdsProvider).onLeft(),
      onShow: () => ref.read(appOpenAdsProvider).onReturned(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the pacing alive while the shell is up.
    ref.watch(appOpenAdsProvider);
    return widget.child;
  }
}
