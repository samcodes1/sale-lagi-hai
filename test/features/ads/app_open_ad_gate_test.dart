import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/presentation/app_open_ad_gate.dart';

import '../../helpers/test_app.dart';

final class _Ads implements AppOpenAds {
  final events = <String>[];

  @override
  void onLeft() => events.add('left');

  @override
  void onReturned() => events.add('returned');
}

void main() {
  testWidgets('reports leaving and coming back', (tester) async {
    final ads = _Ads();
    await tester.pumpWidget(
      testApp(
        const AppOpenAdGate(child: Text('shell')),
        overrides: [appOpenAdsProvider.overrideWithValue(ads)],
      ),
    );
    expect(find.text('shell'), findsOneWidget);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(ads.events, ['left']);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(ads.events, ['left', 'returned']);
  });
}
