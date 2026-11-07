import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/domain/ad_settings.dart';
import 'package:sale_lagi_hai/features/ads/presentation/ad_banner.dart';
import 'package:sale_lagi_hai/features/ads/presentation/ad_break.dart';

import '../../helpers/test_app.dart';

final class _Banner implements LoadedBanner {
  bool disposed = false;

  @override
  double get width => 320;

  @override
  double get height => 100;

  @override
  Widget get view => const Placeholder();

  @override
  void dispose() => disposed = true;
}

final class _Service extends NoAdService {
  new({this.banner, this.native, this.canStart = true});

  final LoadedBanner? banner;
  final LoadedBanner? native;
  final bool canStart;
  AdBannerSize? asked;
  NativeAdColors? nativeColors;

  @override
  bool get enabled => true;

  @override
  Future<bool> start() async => canStart;

  @override
  Future<LoadedBanner?> loadBanner(
    AdBannerSize size, {
    required int width,
  }) async {
    asked = size;
    return banner;
  }

  @override
  Future<LoadedBanner?> loadNative(
    NativeAdColors colors, {
    required int width,
  }) async {
    nativeColors = colors;
    return native;
  }
}

void main() {
  Widget host(
    AdService service, {
    Widget child = const AdBanner(),
    AdSettings settings = const AdSettings(),
  }) => testApp(
    Scaffold(body: Center(child: child)),
    overrides: [
      adServiceProvider.overrideWithValue(service),
      adSettingsProvider.overrideWith((ref) async => settings),
    ],
  );

  testWidgets('shows the banner, labelled, and disposes it', (tester) async {
    final banner = _Banner();
    await tester.pumpWidget(
      host(
        _Service(banner: banner),
        child: const AdBanner(size: AdBannerSize.rectangle),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ad'), findsOneWidget);
    expect(find.byType(Placeholder), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(banner.disposed, isTrue);
  });

  testWidgets('asks for the shape it was given', (tester) async {
    final service = _Service();
    await tester.pumpWidget(
      host(service, child: const AdBanner(size: AdBannerSize.rectangle)),
    );
    await tester.pumpAndSettle();
    expect(service.asked, AdBannerSize.rectangle);
  });

  testWidgets('takes no space when nothing filled', (tester) async {
    await tester.pumpWidget(host(_Service()));
    await tester.pumpAndSettle();
    expect(find.text('Ad'), findsNothing);
    expect(tester.getSize(find.byType(AdBanner)), Size.zero);
  });

  testWidgets('requests nothing without consent', (tester) async {
    final service = _Service(banner: _Banner(), canStart: false);
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    expect(service.asked, isNull);
  });

  testWidgets('a build without ads shows nothing', (tester) async {
    await tester.pumpWidget(host(const NoAdService()));
    await tester.pumpAndSettle();
    expect(find.text('Ad'), findsNothing);
  });

  group('a native slot', () {
    testWidgets('shows a native ad in the app colours', (tester) async {
      final native = _Banner();
      final service = _Service(native: native, banner: _Banner());
      await tester.pumpWidget(
        host(service, child: const AdBanner(size: AdBannerSize.native)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ad'), findsOneWidget);
      expect(service.asked, isNull);
      expect(service.nativeColors, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(native.disposed, isTrue);
    });

    testWidgets('falls back to a rectangle when none fills', (tester) async {
      final service = _Service(banner: _Banner());
      await tester.pumpWidget(
        host(service, child: const AdBanner(size: AdBannerSize.native)),
      );
      await tester.pumpAndSettle();
      expect(service.asked, AdBannerSize.native);
      expect(find.byType(Placeholder), findsOneWidget);
    });

    testWidgets('shows a rectangle when staff turned natives off', (
      tester,
    ) async {
      final service = _Service(native: _Banner(), banner: _Banner());
      await tester.pumpWidget(
        host(
          service,
          child: const AdBanner(size: AdBannerSize.native),
          settings: const AdSettings(nativeEnabled: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.nativeColors, isNull);
      expect(service.asked, AdBannerSize.native);
    });
  });

  testWidgets('the kill switch shows nothing', (tester) async {
    final service = _Service(banner: _Banner());
    await tester.pumpWidget(
      host(service, settings: const AdSettings(enabled: false)),
    );
    await tester.pumpAndSettle();
    expect(service.asked, isNull);
    expect(find.text('Ad'), findsNothing);
  });

  testWidgets('leaving an AdBreak page is a break', (tester) async {
    var breaks = 0;
    final ads = _CountingAds(() => breaks++);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const AdBreak(child: Text('page')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [interstitialsProvider.overrideWithValue(ads)],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(breaks, 0);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(breaks, 1);
  });
}

final class _CountingAds implements Interstitials {
  const new(this._onBreak);

  final void Function() _onBreak;

  @override
  void onBreak() => _onBreak();
}
