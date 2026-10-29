// QA (sub-phase 1.3, round 2): tries to break the round-1 fixes.
// - A generic scanner: every text run and icon glyph painted by a widget
//   catalogue is checked against the fill actually painted behind it, in
//   light, dark and both high-contrast themes.
// - IconButton variants x toggle state x theme.
// - Disabled states of the new component themes.
// - Widgets that pull `primary` and were not covered in round 1.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of a bug
// that is open in docs/qa/1.3.md (see known_bugs.dart).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/theme/accent_primary.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';

import 'known_bugs.dart';

double _channel(double v) {
  final c = (v * 255).round() / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrastOf(Color fg, Color bg) {
  final f = fg.a < 1 ? Color.alphaBlend(fg, bg) : fg;
  final a = _lum(f);
  final b = _lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

String _hex(Color c) {
  final argb = c.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2).toUpperCase()}';
}

/// The fill painted behind [element] (translucent layers composited).
Color backgroundOfElement(Element element) {
  final layers = <Color>[];
  Color? base;
  element.visitAncestorElements((e) {
    final w = e.widget;
    Color? c;
    if (w is Material && w.type != MaterialType.transparency) c = w.color;
    if (w is ColoredBox) c = w.color;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      c = (w.decoration as BoxDecoration).color;
    }
    if (w is Ink && w.decoration is BoxDecoration) {
      c = (w.decoration! as BoxDecoration).color;
    }
    if (w is Scaffold) c = Theme.of(e).scaffoldBackgroundColor;
    if (c == null || c.a == 0) return true;
    if (c.a < 1) {
      layers.add(c);
      return true;
    }
    base = c;
    return false;
  });
  var out = base ?? Theme.of(element).scaffoldBackgroundColor;
  for (final layer in layers.reversed) {
    out = Color.alphaBlend(layer, out);
  }
  return out;
}

bool _isVisible(Element e) {
  var visible = true;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Opacity && w.opacity == 0) visible = false;
    if (w is FadeTransition && w.opacity.value == 0) visible = false;
    if (w is Offstage && w.offstage) visible = false;
    if (w is Visibility && !w.visible) visible = false;
    return visible;
  });
  return visible;
}

/// Navigation destinations paint their selection indicator as a sibling of
/// the icon, so the ancestor walk can't see it. Those icons are checked
/// against the indicator directly in round 1 and the product tests.
bool _inNavigation(Element e) {
  var found = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    found = w is NavigationRail || w is NavigationBar || w is NavigationDrawer;
    return !found;
  });
  return found;
}

/// Every painted text run or icon whose contrast with its fill is too low.
/// Disabled content (alpha ≤ 0.5, e.g. 38% onSurface) is exempt (WCAG).
List<String> lowContrastRuns(WidgetTester tester) {
  final out = <String>[];
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!p.attached || p.size.isEmpty) continue;
    final creator = p.debugCreator;
    if (creator is! DebugCreator) continue;
    final element = creator.element;
    if (!_isVisible(element)) continue;
    final style0 = p.text.style;
    if (style0?.fontFamily == 'MaterialIcons' && _inNavigation(element)) {
      continue;
    }
    final style = p.text.style;
    final color = style?.color;
    if (color == null || color.a <= 0.5) continue;
    final text = p.text.toPlainText().trim();
    if (text.isEmpty) continue;
    final isIcon = style?.fontFamily == 'MaterialIcons';
    final bg = backgroundOfElement(element);
    final r = contrastOf(color, bg);
    final need = isIcon ? 3.0 : 4.5;
    if (r < need) {
      final label = isIcon
          ? 'icon U+${text.runes.first.toRadixString(16)}'
          : '"$text"';
      out.add('$label ${_hex(color)} on ${_hex(bg)} = ${r.toStringAsFixed(2)}');
    }
  }
  return out;
}

final _themes = <String, ThemeData Function()>{
  'light': AppTheme.light,
  'dark': AppTheme.dark,
  'light HC': () =>
      AppTheme.build(brightness: Brightness.light, highContrast: true),
  'dark HC': () =>
      AppTheme.build(brightness: Brightness.dark, highContrast: true),
};

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget body) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // Developer edit (1.6): design-system widgets read AppLocalizations.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: body)),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _opener(String label, void Function(BuildContext) open) => Builder(
  builder: (context) =>
      TextButton(onPressed: () => open(context), child: Text(label)),
);

/// Widgets that pull `primary` somewhere, beyond the round-1 list.
Widget _catalogue() => ListView(
  padding: const EdgeInsets.all(8),
  children: [
    const CircleAvatar(child: Text('SK')),
    SizedBox(
      height: 220,
      child: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bookmark_outline),
                label: Text('Saved'),
              ),
            ],
          ),
          const Expanded(
            child: NavigationDrawer(
              children: [
                NavigationDrawerDestination(
                  icon: Icon(Icons.inbox),
                  label: Text('Inbox'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.send),
                  label: Text('Sent'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const Card.filled(
      child: ListTile(title: Text('Filled card'), subtitle: Text('Subtitle')),
    ),
    const Card.outlined(
      child: ListTile(title: Text('Outlined'), subtitle: Text('Subtitle')),
    ),
    CheckboxListTile(
      selected: true,
      value: true,
      onChanged: (_) {},
      title: const Text('Selected checkbox tile'),
      subtitle: const Text('Subtitle'),
      secondary: const Icon(Icons.credit_card),
    ),
    RadioGroup<int>(
      groupValue: 1,
      onChanged: (_) {},
      child: const RadioListTile<int>(
        selected: true,
        value: 1,
        title: Text('Selected radio tile'),
      ),
    ),
    const ExpansionTile(
      initiallyExpanded: true,
      title: Text('Expanded'),
      subtitle: Text('Sub'),
      leading: Icon(Icons.local_offer),
      children: [Text('child')],
    ),
    DataTable(
      sortColumnIndex: 0,
      columns: const [
        DataColumn(label: Text('Brand')),
        DataColumn(label: Text('Off'), numeric: true),
      ],
      rows: [
        DataRow(
          selected: true,
          onSelectChanged: (_) {},
          cells: const [DataCell(Text('Khaadi')), DataCell(Text('40%'))],
        ),
      ],
    ),
    MaterialBanner(
      content: const Text('You are offline'),
      leading: const Icon(Icons.wifi_off),
      actions: [TextButton(onPressed: () {}, child: const Text('Retry'))],
    ),
    MenuBar(
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(onPressed: () {}, child: const Text('Share')),
          ],
          child: const Text('File'),
        ),
      ],
    ),
    InputChip(
      label: const Text('Clifton'),
      selected: true,
      onSelected: (_) {},
      onDeleted: () {},
    ),
    ChoiceChip(label: const Text('Lahore'), selected: true, onSelected: (_) {}),
    const TextField(
      decoration: InputDecoration(
        labelText: 'With error',
        errorText: 'Enter a city',
        prefixIcon: Icon(Icons.place),
        suffixIcon: Icon(Icons.clear),
        helperText: 'Helper',
        counterText: '3/20',
      ),
    ),
    const Tooltip(message: 'Tip', child: Text('Tooltip host')),
    FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
    FloatingActionButton.extended(
      onPressed: () {},
      icon: const Icon(Icons.add),
      label: const Text('New alert'),
    ),
    const ListTile(enabled: false, title: Text('Disabled tile')),
  ],
);

void main() {
  group('generic scanner: no low-contrast text or icon anywhere', () {
    for (final MapEntry(key: name, value: theme) in _themes.entries) {
      testWidgets('catalogue, $name', (tester) async {
        await _pump(tester, theme(), _catalogue());
        expect(lowContrastRuns(tester), isEmpty);
      });
    }
  });

  group('IconButton variants (round-1 BUG-7 fix)', () {
    Widget variant(String kind, {bool? selected}) {
      const icon = Icon(Icons.favorite_border);
      const sel = Icon(Icons.favorite);
      void tap() {}
      return switch (kind) {
        'standard' => IconButton(
          tooltip: kind,
          isSelected: selected,
          onPressed: tap,
          icon: icon,
          selectedIcon: sel,
        ),
        'filled' => IconButton.filled(
          tooltip: kind,
          isSelected: selected,
          onPressed: tap,
          icon: icon,
          selectedIcon: sel,
        ),
        'tonal' => IconButton.filledTonal(
          tooltip: kind,
          isSelected: selected,
          onPressed: tap,
          icon: icon,
          selectedIcon: sel,
        ),
        _ => IconButton.outlined(
          tooltip: kind,
          isSelected: selected,
          onPressed: tap,
          icon: icon,
          selectedIcon: sel,
        ),
      };
    }

    for (final MapEntry(key: name, value: theme) in _themes.entries) {
      testWidgets('all variants x toggle state, $name', (tester) async {
        // Developer edit (1.6): toggle IconButtons go through
        // AccentPrimary, the documented fix for R2-1.
        await _pump(
          tester,
          theme(),
          AccentPrimary(
            child: Wrap(
              children: [
                for (final kind in ['standard', 'filled', 'tonal', 'outlined'])
                  for (final selected in [null, false, true])
                    KeyedSubtree(
                      key: ValueKey('$kind/$selected'),
                      child: variant(kind, selected: selected),
                    ),
              ],
            ),
          ),
        );
        final failures = <String>[];
        for (final kind in ['standard', 'filled', 'tonal', 'outlined']) {
          for (final selected in [null, false, true]) {
            final host = find.byKey(ValueKey('$kind/$selected'));
            final glyph = find.descendant(
              of: host,
              matching: find.byType(RichText),
            );
            final p = tester.renderObject<RenderParagraph>(glyph.first);
            final fg = p.text.style!.color!;
            final bg = backgroundOfElement(tester.element(glyph.first));
            final r = contrastOf(fg, bg);
            if (r < 3) {
              failures.add(
                '$kind isSelected=$selected: ${_hex(fg)} on ${_hex(bg)} '
                '= ${r.toStringAsFixed(2)}',
              );
            }
          }
        }
        expect(failures, isEmpty);
      });
    }

    testWidgets('selected toggle is visibly different from unselected', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.light(),
        Row(
          children: [
            KeyedSubtree(
              key: const ValueKey('on'),
              child: variant('standard', selected: true),
            ),
            KeyedSubtree(
              key: const ValueKey('off'),
              child: variant('standard', selected: false),
            ),
          ],
        ),
      );
      Color c(String k) => tester
          .renderObject<RenderParagraph>(
            find
                .descendant(
                  of: find.byKey(ValueKey(k)),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .style!
          .color!;
      expect(c('on'), isNot(c('off')));
    });
  });

  group('disabled states of the new component themes', () {
    testWidgets('DatePicker: days outside firstDate/lastDate look disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.light(),
        _opener(
          'open',
          (c) => showDatePicker(
            context: c,
            initialDate: DateTime(2026, 10, 15),
            currentDate: DateTime(2026, 10, 29),
            firstDate: DateTime(2026, 10, 10),
            lastDate: DateTime(2026, 10, 20),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      Color day(String d) => tester
          .renderObject<RenderParagraph>(
            find
                .descendant(of: find.byType(Dialog), matching: find.text(d))
                .first,
          )
          .text
          .style!
          .color!;
      final enabled = day('12');
      final disabled = day('5');
      final today = day('29');
      expect(
        disabled,
        isNot(enabled),
        reason: 'disabled day ${_hex(disabled)} == enabled ${_hex(enabled)}',
      );
      expect(today.a, lessThan(1), reason: 'disabled "today" ${_hex(today)}');
    });

    testWidgets('SegmentedButton: a disabled segment looks disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.light(),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Near')),
            ButtonSegment(value: 1, label: Text('All'), enabled: false),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      );
      final enabledFg = tester
          .renderObject<RenderParagraph>(find.text('Near'))
          .text
          .style!
          .color!;
      final disabledFg = tester
          .renderObject<RenderParagraph>(find.text('All'))
          .text
          .style!
          .color!;
      final s = AppTheme.light().colorScheme;
      expect(enabledFg, s.onSecondaryContainer);
      expect(
        disabledFg.a,
        lessThan(0.5),
        reason: 'disabled segment is ${_hex(disabledFg)} (full onSurface)',
      );
    });

    testWidgets('Elevated / Toggle disabled are dimmed', (tester) async {
      await _pump(
        tester,
        AppTheme.light(),
        Column(
          children: [
            const ElevatedButton(onPressed: null, child: Text('Elevated off')),
            ToggleButtons(
              isSelected: const [true, false],
              children: const [Text('Toggle off A'), Text('Toggle off B')],
            ),
          ],
        ),
      );
      for (final t in ['Elevated off', 'Toggle off A', 'Toggle off B']) {
        final c = tester
            .renderObject<RenderParagraph>(find.text(t))
            .text
            .style!
            .color!;
        expect(c.a, lessThan(0.5), reason: '$t is ${_hex(c)}');
      }
    });
  });

  group('primary-pulling widgets not covered in round 1', () {
    testWidgets('Stepper connector line is not a thin Haldi mark', (
      tester,
    ) async {
      // Developer edit (1.6): AppStepper, the design-system Stepper (R2-4).
      await _pump(
        tester,
        AppTheme.light(),
        const AppStepper(
          currentStep: 1,
          steps: [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
            Step(title: Text('B'), content: Text('b'), isActive: true),
            Step(title: Text('C'), content: SizedBox()),
          ],
        ),
      );
      final lines = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color)
          .whereType<Color>()
          .where((c) => c == BrandColors.haldi500);
      // Step circles are Haldi fills with ink digits (fine); the vertical
      // connector is a 1dp Container in the active colour.
      final connectors = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) =>
                c.color == BrandColors.haldi500 &&
                (c.constraints?.maxWidth ?? 2) <= 1,
          );
      expect(connectors, isEmpty, reason: '${lines.length} Haldi containers');
    });

    testWidgets('DateRangePicker: no Haldi text', (tester) async {
      // Developer edit (1.6): the app's date-range picker (R2-4).
      await _pump(
        tester,
        AppTheme.light(),
        _opener(
          'open',
          (c) => showAppDateRangePicker(
            context: c,
            initialDateRange: DateTimeRange(
              start: DateTime(2026, 10, 10),
              end: DateTime(2026, 10, 14),
            ),
            currentDate: DateTime(2026, 10, 29),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(lowContrastRuns(tester), isEmpty);
    });

    testWidgets('RangeSlider and value indicators', (tester) async {
      await _pump(
        tester,
        AppTheme.light(),
        RangeSlider(
          values: const RangeValues(0.2, 0.6),
          divisions: 5,
          labels: const RangeLabels('20%', '60%'),
          onChanged: (_) {},
        ),
      );
      final theme = SliderTheme.of(tester.element(find.byType(RangeSlider)));
      expect(theme.activeTrackColor, BrandLight.secondary);
      expect(theme.thumbColor, BrandLight.secondary);
    });

    test('no raw RefreshIndicator in lib/ outside AppRefreshIndicator', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('app_refresh_indicator.dart')) continue;
        final src = f.readAsStringSync();
        if (RegExp(r'\bRefreshIndicator(\.adaptive)?\(').hasMatch(src)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('round-2 findings in widgets outside round 1', () {
    for (final MapEntry(key: name, value: theme) in _themes.entries) {
      testWidgets(
        'SwitchListTile(selected: true) title stays readable, $name',
        // Developer note (1.6): resolved by policy, not theme. `selected:`
        // on SwitchListTile is banned in lib/ by
        // test/design_system/design_system_guard_test.dart; this keeps
        // the original reproducer for reference.
        skip: knownBug('1.3 R2-5 (banned by guard test)') != false,
        (tester) async {
          await _pump(
            tester,
            theme(),
            SwitchListTile(
              selected: true,
              value: true,
              onChanged: (_) {},
              title: const Text('Selected switch tile'),
            ),
          );
          expect(lowContrastRuns(tester), isEmpty);
        },
      );

      testWidgets('Stepper step numbers on their circles, $name', (
        tester,
      ) async {
        await _pump(
          tester,
          theme(),
          // Developer edit (1.6): AppStepper, the design-system Stepper.
          const AppStepper(
            currentStep: 1,
            steps: [
              Step(title: Text('City'), content: SizedBox(), isActive: true),
              Step(title: Text('Food'), content: Text('pick'), isActive: true),
              Step(title: Text('Alerts'), content: SizedBox()),
            ],
          ),
        );
        expect(lowContrastRuns(tester), isEmpty);
      });
    }
  });

  group('dark surfaces after the remap (round-1 BUG-18 fix)', () {
    testWidgets('cards, chips and inputs are lighter than the background', (
      tester,
    ) async {
      final s = AppTheme.dark().colorScheme;
      final bg = AppTheme.dark().scaffoldBackgroundColor;
      expect(_lum(s.surfaceContainerLowest), greaterThan(_lum(bg)));
      expect(
        _lum(s.surfaceContainerLow),
        greaterThanOrEqualTo(_lum(s.surfaceContainerLowest)),
      );
      expect(
        _lum(s.surfaceContainerHighest),
        greaterThanOrEqualTo(_lum(s.surfaceContainerHigh)),
      );
    });

    for (final MapEntry(key: name, value: theme) in {
      'dark': AppTheme.dark,
      'dark HC': () =>
          AppTheme.build(brightness: Brightness.dark, highContrast: true),
    }.entries) {
      testWidgets('SearchBar hint on surfaceContainerHigh, $name', (
        tester,
      ) async {
        await _pump(
          tester,
          theme(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: SearchBar(hintText: 'Search deals'),
          ),
        );
        expect(lowContrastRuns(tester), isEmpty);
      });
    }

    test('secondary text and outlines on every dark container', () {
      final s = AppTheme.dark().colorScheme;
      final rows = <String>[];
      for (final (name, c) in [
        ('lowest', s.surfaceContainerLowest),
        ('low', s.surfaceContainerLow),
        ('container', s.surfaceContainer),
        ('high', s.surfaceContainerHigh),
        ('highest', s.surfaceContainerHighest),
      ]) {
        rows.add(
          '$name ${_hex(c)}: onSurfaceVariant '
          '${contrastOf(s.onSurfaceVariant, c).toStringAsFixed(2)}, '
          'secondary ${contrastOf(s.secondary, c).toStringAsFixed(2)}, '
          'outline ${contrastOf(s.outline, c).toStringAsFixed(2)}',
        );
      }
      // Reported, not asserted (which pairs matter depends on the widget).
      // ignore: avoid_print
      print(rows.join('\n'));
    });
  });

  group('high contrast: exhaustive text-pair audit (7:1)', () {
    for (final b in Brightness.values) {
      test(b.name, () {
        final t = AppTheme.build(brightness: b, highContrast: true);
        final s = t.colorScheme;
        final d = t.extension<DealColors>()!;
        final surfaces = <String, Color>{
          'background': t.scaffoldBackgroundColor,
          'surface': s.surface,
          'lowest': s.surfaceContainerLowest,
          'low': s.surfaceContainerLow,
          'container': s.surfaceContainer,
          'high': s.surfaceContainerHigh,
          'highest': s.surfaceContainerHighest,
        };
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (s.onPrimary, s.primary),
          'onPrimaryContainer': (s.onPrimaryContainer, s.primaryContainer),
          'onSecondary/secondary': (s.onSecondary, s.secondary),
          'onSecondaryContainer': (
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
          'onTertiary/tertiary': (s.onTertiary, s.tertiary),
          'onTertiaryContainer': (s.onTertiaryContainer, s.tertiaryContainer),
          'onError/error': (s.onError, s.error),
          'onErrorContainer': (s.onErrorContainer, s.errorContainer),
          'error/errorContainer': (s.error, s.errorContainer),
          'onInverseSurface': (s.onInverseSurface, s.inverseSurface),
          'inversePrimary/inverseSurface': (s.inversePrimary, s.inverseSurface),
          'onDeal/deal': (d.onDeal, d.deal),
          'onDealContainer': (d.onDealContainer, d.dealContainer),
          'onFeatured/featured': (d.onFeatured, d.featured),
          'success/successContainer': (d.success, d.successContainer),
          'warning/warningContainer': (d.warning, d.warningContainer),
          'info/infoContainer': (d.info, d.infoContainer),
          for (final MapEntry(key: n, value: c) in surfaces.entries) ...{
            'onSurface/$n': (s.onSurface, c),
            'onSurfaceVariant/$n': (s.onSurfaceVariant, c),
            'secondary/$n': (s.secondary, c),
            'error/$n': (s.error, c),
            'success/$n': (d.success, c),
            'warning/$n': (d.warning, c),
            'info/$n': (d.info, c),
          },
        };
        final below = [
          for (final MapEntry(key: k, value: (fg, bg)) in pairs.entries)
            if (contrastOf(fg, bg) < 7)
              '$k ${contrastOf(fg, bg).toStringAsFixed(2)}',
        ];
        expect(below, isEmpty);
      });
    }
  });
}
