# Test recipes

## 1. Golden tests with alchemist 0.14.1 + material_ui (verified)
alchemist builds its own `MaterialApp` from the **old** `package:flutter/material.dart`. Without a host, material_ui widgets (Chip, buttons, text fields…) throw **"No MaterialLocalizations found"**. Host every scenario like this:

```dart
// test/helpers/golden_host.dart
Widget goldenHost(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) =>
    Localizations(
      locale: locale,
      delegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      child: Theme(
        data: buildTheme(brightness),
        child: Material(child: child),   // Directionality comes from the Localizations (ur → RTL)
      ),
    );

// test/design_system/discount_badge_golden_test.dart
void main() {
  goldenTest(
    'DiscountBadge',
    fileName: 'discount_badge',
    constraints: const BoxConstraints(maxWidth: 400),
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final b in Brightness.values)
          for (final l in const [Locale('en'), Locale('ur')])
            GoldenTestScenario(
              name: '${b.name} ${l.languageCode}',
              child: goldenHost(const DiscountBadge(percent: 40), locale: l, brightness: b),
            ),
      ],
    ),
  );
}
```
- **CI vs platform goldens.** alchemist writes `goldens/ci/*.png` (text drawn as Ahem blocks, so it's stable across OSes) and `goldens/<platform>/*.png` (real fonts). CI compares the `ci` set.
  - Review the platform set by eye for typography: Nastaliq clipping is only visible there.
  - Platform goldens need the real fonts loaded. In `test/flutter_test_config.dart`, load each bundled family with `FontLoader('NotoNastaliqUrdu')..addFont(rootBundle.load('assets/fonts/…'))` and `await loader.load()`. `loadAppFonts()` belongs to the discontinued golden_toolkit, so don't use it.
- **Text-scale goldens:** wrap with `MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2)), child: …)` inside the host.
- **Tag goldens** (`tags: ['golden']`, declared in `dart_test.yaml`) so they can run separately. Updating them is deliberate: `flutter test --update-goldens --tags golden`, then review the PNG diff.
- `golden_toolkit` is **discontinued** on pub.dev. Don't use it. Plain `matchesGoldenFile` also works with material_ui, because `MaterialApp` there is the material_ui one.

## 2. Widget tests: all states
```dart
group('FeedScreen', () {
  for (final (name, override, finder) in [
    ('loading', feedProvider(city: 'lahore').overrideWith(() => _NeverCompletes()), find.byType(DealCardSkeleton)),
    ('empty',   feedRepositoryProvider.overrideWithValue(FakeFeedRepository(deals: [])), find.byType(EmptyView)),
    ('error',   feedRepositoryProvider.overrideWithValue(FakeFeedRepository(failure: const Failure.network())), find.byType(ErrorView)),
    ('data',    feedRepositoryProvider.overrideWithValue(FakeFeedRepository(deals: [fixtureDeal])), find.byType(DealCard)),
  ]) {
    testWidgets(name, (tester) async {
      await tester.pumpApp(const FeedScreen(), overrides: [override]);
      await tester.pump(const Duration(milliseconds: 50));
      expect(finder, findsWidgets);
    });
  }
});
```
- Use `pump(duration)` instead of `pumpAndSettle()` when something animates forever (shimmer, countdown).
- Disable Riverpod auto-retry in tests (`ProviderScope(retry: (_, _) => null)`), or error states take seconds to appear.
- Images: wrap in `mockNetworkImages(() async { … })` (mocktail_image_network).
- Time: inject `clock` and use `withClock(Clock.fixed(...))` for expiry and countdown tests. Test the Asia/Karachi boundaries: just before and after midnight, and UTC+5.

## 3. RTL, Urdu and text-scale widget checks
```dart
testWidgets('DealCard in Urdu at 200% text has no overflow', (tester) async {
  tester.view..physicalSize = const Size(720, 1600)..devicePixelRatio = 2;   // 360×800 dp
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(() { tester.view.reset(); tester.platformDispatcher.clearTextScaleFactorTestValue(); });
  await tester.pumpApp(DealCard(deal: longUrduDeal), locale: const Locale('ur'));
  expect(tester.takeException(), isNull);                         // RenderFlex overflow would surface here
  expect(Directionality.of(tester.element(find.byType(DealCard))), TextDirection.rtl);
  final badge = tester.getTopLeft(find.byType(DiscountBadge));
  expect(badge.dx, lessThan(180));                                 // top-END corner = left side in RTL
});
```
Use realistic long Urdu fixtures (for example 2× the English length), brand names in Latin script inside Urdu text, and numbers with %.

## 4. Riverpod test patterns
- **Unit:** `ProviderContainer.test(overrides: […], retry: (_, _) => null)`. Keep auto-dispose providers alive with `container.listen(provider, (_, _) {})`.
- **Errors:** `await container.read(p.future)` throws the raw `Failure`. `requireValue` throws `ProviderException` (from `package:flutter_riverpod/misc.dart`).
- **Widget:** `tester.container()` gives the scope's container. `NotifierProvider.overrideWithBuild` mocks only `build`.
- **Mock repositories and gateways, not notifiers.** Prefer hand-written fakes with in-memory state. Use mocktail `when/verify` for interaction checks, and call `registerFallbackValue` for custom argument types.

## 5. Integration flows (integration_test; patrol for native UI)
```dart
// integration_test/flows/save_deal_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('onboarding → feed → deal → save', (tester) async {
    await app.bootstrap(overrides: testBackendOverrides);   // staging or local backend; never prod
    await tester.pumpAndSettle();
    await tester.tap(find.text('English')); await tester.pumpAndSettle();
    // … pick city, categories, open first deal, tap save, assert snackbar + Saved tab count
  });
}
```
- Run it with `flutter test integration_test --flavor dev --dart-define-from-file=env/dev.json` on an emulator.
- Native permission dialogs (`POST_NOTIFICATIONS`, location) need **patrol** 4.10 (`$.native.grantPermissionWhenInUse()`), or pre-grant with `adb shell pm grant`.

## 6. Coverage computation (changed files)
```bash
flutter test --coverage
# lcov may not be installed; tool/check_coverage.dart (repo) is the source of truth.
# For per-file numbers on the files changed since the last gate:
git diff --name-only <last-gate-commit> -- 'lib/**.dart' | grep -vE '\.(g|freezed)\.dart$' > /tmp/changed.txt
awk -v files=/tmp/changed.txt 'BEGIN{while((getline f<files)>0) want[f]=1}
  /^SF:/{f=substr($0,4); keep=(f in want)} keep&&/^LF:/{lf+=substr($0,4)} keep&&/^LH:/{lh+=substr($0,4)}
  END{printf "changed-files coverage: %.1f%% (%d/%d)\n", lh*100/lf, lh, lf}' coverage/lcov.info
```
Files that no test imports don't appear in `lcov.info` at all. Count them as 0% (cross-check with the changed-file list). QA report 1.1 shows this pitfall.

## 7. Flaky-test rules
- No real network, clock or timers in unit and widget tests. Inject `clock` and use fakes.
- No `sleep` or arbitrary delays; pump explicit durations.
- A test that fails intermittently is a bug: file it (S3, or S2 if it masks a real failure) and quarantine it with a tag *and* an issue link. Never delete it.
- Goldens: pin the Flutter version (CI uses the `FLUTTER_VERSION` env) and use the alchemist CI variant to avoid font-rendering drift.
