import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/sponsors/application/sponsor_providers.dart';
import 'package:sale_lagi_hai/features/sponsors/data/backend_sponsor_repository.dart';
import 'package:sale_lagi_hai/features/sponsors/domain/sponsor_banner.dart';
import 'package:sale_lagi_hai/features/sponsors/presentation/sponsor_carousel.dart';

import '../../helpers/test_app.dart';

Map<String, Object?> _row({
  String id = '1',
  String title = 'Lawn sale',
  String? cityId,
  String? link,
}) => {
  'id': id,
  'sponsor_name': 'Acme',
  'title_en': title,
  'title_ur': null,
  'subtitle_en': null,
  'subtitle_ur': null,
  'image_path': null,
  'link_url': link,
  'city_id': cityId,
};

final class _Gateway implements BackendGateway {
  new(this.rows);

  final List<Map<String, Object?>> rows;
  TableQuery? query;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    this.query = query;
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => throw UnimplementedError();

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      throw UnimplementedError();
}

final class _Links implements LinkService {
  final opened = <String>[];

  @override
  Future<bool> openWeb(String url) async {
    opened.add(url);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'Test',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

void main() {
  group('BackendSponsorRepository', () {
    test('reads the banners in staff order, capped', () async {
      final backend = _Gateway([_row()]);
      final banners = await BackendSponsorRepository(backend).live();
      expect(banners.single.sponsorName, 'Acme');
      expect(backend.query?.table, 'sponsor_banners');
      expect(backend.query?.orderBy, 'sort_order');
      expect(backend.query?.limit, 8);
    });

    test('a malformed row is an error', () {
      expect(
        BackendSponsorRepository(
          _Gateway([
            {'id': 1},
          ]),
        ).live(),
        throwsFormatException,
      );
    });

    test('the demo backend has sample banners', () async {
      final banners = await BackendSponsorRepository(DemoGateway()).live();
      expect(banners, isNotEmpty);
      expect(banners.first.title(urdu: true), isNot(banners.first.titleEn));
    });
  });

  test('Urdu falls back to English', () {
    const banner = SponsorBanner(id: '1', sponsorName: 'A', titleEn: 'Sale');
    expect(banner.title(urdu: true), 'Sale');
    expect(banner.subtitle(urdu: true), isNull);
  });

  group('sponsorBannersProvider', () {
    ProviderContainer container(BackendGateway backend, {String? city}) {
      final c = ProviderContainer(
        overrides: [
          backendGatewayProvider.overrideWithValue(backend),
          homeCityProvider.overrideWithValue(city),
          loggerProvider.overrideWithValue(
            AppLogger(minLevel: LogLevel.error, sinks: const []),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('keeps national banners and this city only', () async {
      final c = container(
        _Gateway([
          _row(),
          _row(id: '2', cityId: 'karachi'),
          _row(id: '3', cityId: 'lahore'),
        ]),
        city: 'karachi',
      );
      final banners = await c.read(sponsorBannersProvider.future);
      expect(banners.map((b) => b.id), ['1', '2']);
    });

    test('a failure means no banners, never an error', () async {
      final c = container(
        _Gateway([
          {'id': 1},
        ]),
      );
      expect(await c.read(sponsorBannersProvider.future), isEmpty);
    });
  });

  group('SponsorCarousel', () {
    Widget host(
      List<Map<String, Object?>> rows, {
      LinkService? links,
      Locale locale = AppLocales.english,
    }) => testApp(
      const Scaffold(body: SponsorCarousel()),
      locale: locale,
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        backendGatewayProvider.overrideWithValue(_Gateway(rows)),
        homeCityProvider.overrideWithValue(null),
        if (links != null) linkServiceProvider.overrideWithValue(links),
      ],
    );

    testWidgets('nothing shows without banners', (tester) async {
      await tester.pumpWidget(host(const []));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('is labelled Sponsored and heard with its sponsor', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host([_row()]));
      await tester.pumpAndSettle();
      expect(find.text('Sponsored'), findsOneWidget);
      expect(find.text('Lawn sale'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sponsored by Acme: Lawn sale'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a tap opens the link', (tester) async {
      final links = _Links();
      await tester.pumpWidget(
        host([_row(link: 'https://acme.example/sale')], links: links),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lawn sale'));
      expect(links.opened, ['https://acme.example/sale']);
    });

    testWidgets('moves on by itself, and wraps round', (tester) async {
      await tester.pumpWidget(
        host([_row(), _row(id: '2', title: 'Eid offer')]),
      );
      await tester.pumpAndSettle();
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(pages.page, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(pages.page, 0);
    });

    testWidgets('stays still with reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        host([_row(), _row(id: '2', title: 'Eid offer')]),
      );
      await tester.pumpAndSettle();
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(pages.page, 0);
    });

    testWidgets('grows with 200% text and does not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(host([_row()], locale: AppLocales.urdu));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
