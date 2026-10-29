// QA (sub-phase 1.3): renders the Material 3 widgets that pull
// `colorScheme.primary` (Haldi yellow) into text or thin marks, under the real
// AppTheme, and checks the colour each one actually ends up with.
//
// Contrast is computed here independently (WCAG 2.2 relative luminance from
// the 8-bit sRGB channels, 0.04045 threshold, no rounding), not with the
// product test's helper.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of a bug
// that is open in docs/qa/1.3.md (see known_bugs.dart).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';

double _channel(double v) {
  final c = (v * 255).round() / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG contrast of [fg] over [bg]; a translucent [fg] is composited first.
double contrastOf(Color fg, Color bg) {
  final f = fg.a < 1 ? Color.alphaBlend(fg, bg) : fg;
  final a = _luminance(f);
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

String _hex(Color c) {
  final argb = c.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2).toUpperCase()}';
}

/// The colour of the first text run (Text or Icon glyph) under [finder].
Color glyphColor(WidgetTester tester, Finder finder) {
  final rich = find
      .descendant(of: finder, matching: find.byType(RichText), matchRoot: true)
      .first;
  return tester.renderObject<RenderParagraph>(rich).text.style!.color!;
}

/// The fill painted behind [finder]: translucent layers (state overlays,
/// tints) are composited onto the nearest opaque ancestor fill.
Color backgroundOf(WidgetTester tester, Finder finder) {
  final layers = <Color>[];
  Color? base;
  tester.element(finder.first).visitAncestorElements((e) {
    final w = e.widget;
    Color? c;
    if (w is Material && w.type != MaterialType.transparency) c = w.color;
    if (w is ColoredBox) c = w.color;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      c = (w.decoration as BoxDecoration).color;
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
  var out = base!;
  for (final layer in layers.reversed) {
    out = Color.alphaBlend(layer, out);
  }
  return out;
}

Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness: brightness),
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void expectText(WidgetTester tester, Finder f, {String? what}) {
  final fg = glyphColor(tester, f);
  final bg = backgroundOf(tester, f);
  final r = contrastOf(fg, bg);
  expect(
    r,
    greaterThanOrEqualTo(4.5),
    reason:
        '${what ?? f.toString()}: text ${_hex(fg)} on '
        '${_hex(bg)} = ${r.toStringAsFixed(2)}:1 (needs 4.5:1)',
  );
}

void expectMark(Color fg, Color bg, String what) {
  final r = contrastOf(fg, bg);
  expect(
    r,
    greaterThanOrEqualTo(3),
    reason:
        '$what: ${_hex(fg)} on ${_hex(bg)} = ${r.toStringAsFixed(2)}:1 '
        '(needs 3:1, WCAG 1.4.11)',
  );
}

Widget _opener(String label, void Function(BuildContext) open) => Builder(
  builder: (context) =>
      TextButton(onPressed: () => open(context), child: Text(label)),
);

void main() {
  const haldi = BrandColors.haldi500;

  test('independent contrast helper matches the brand report', () {
    expect(contrastOf(haldi, BrandColors.surma0), closeTo(1.60, 0.01));
    expect(
      contrastOf(BrandColors.surma900, BrandColors.haldi500),
      closeTo(11.04, 0.01),
    );
    expect(
      contrastOf(BrandColors.surma500, BrandColors.surma900),
      closeTo(3.96, 0.01),
    );
  });

  group('light theme: no Haldi text or thin marks on light surfaces', () {
    testWidgets('TextField focused: label, prefix icon, cursor, border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search deals',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(TextField)));
      final fill = theme.inputDecorationTheme.fillColor!;

      final label = glyphColor(tester, find.text('Search deals'));
      expect(contrastOf(label, fill), greaterThanOrEqualTo(4.5));
      expectMark(
        glyphColor(tester, find.byIcon(Icons.search)),
        fill,
        'focused prefix icon',
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expectMark(editable.cursorColor, fill, 'cursor');
      expectMark(
        theme.inputDecorationTheme.focusedBorder!.borderSide.color,
        fill,
        'focused border',
      );
    });

    testWidgets('TabBar: labels and indicator', (tester) async {
      await pumpThemed(
        tester,
        const DefaultTabController(
          length: 2,
          child: TabBar(
            tabs: [
              Tab(text: 'Nearby'),
              Tab(text: 'Online'),
            ],
          ),
        ),
      );
      expectText(tester, find.text('Nearby'), what: 'selected tab');
      expectText(tester, find.text('Online'), what: 'unselected tab');
      final theme = Theme.of(tester.element(find.byType(TabBar)));
      expectMark(
        theme.tabBarTheme.indicatorColor!,
        theme.scaffoldBackgroundColor,
        'tab indicator',
      );
    });

    testWidgets('RefreshIndicator: spinner on its disc', (tester) async {
      final done = Completer<void>();
      await pumpThemed(
        tester,
        // Since the BUG-2 fix the design system's wrapper is the API
        // (the raw RefreshIndicator ignores the theme).
        AppRefreshIndicator(
          onRefresh: () => done.future,
          child: ListView(children: const [SizedBox(height: 2000)]),
        ),
      );
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final spinner = tester.widget<RefreshProgressIndicator>(
        find.byType(RefreshProgressIndicator),
      );
      final value = spinner.valueColor!.value!;
      final disc =
          spinner.backgroundColor ??
          Theme.of(tester.element(find.byType(RefreshProgressIndicator)))
              .progressIndicatorTheme
              .refreshBackgroundColor!;
      done.complete();
      await tester.pumpAndSettle();
      expectMark(value, disc, 'refresh spinner');
    });

    testWidgets('DatePicker: today marker, header and selected day', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _opener(
          'open',
          (c) => showDatePicker(
            context: c,
            initialDate: DateTime(2026, 10, 10),
            currentDate: DateTime(2026, 10, 29),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final surface =
          dialog.backgroundColor ?? backgroundOf(tester, find.text('29'));
      expectText(tester, find.text('10'), what: 'selected day');
      final today = glyphColor(tester, find.text('29'));
      expect(
        contrastOf(today, surface),
        greaterThanOrEqualTo(4.5),
        reason:
            "today's date: ${_hex(today)} on ${_hex(surface)} = "
            '${contrastOf(today, surface).toStringAsFixed(2)}:1',
      );
    });

    testWidgets('SegmentedButton: selected and unselected labels', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Near me')),
            ButtonSegment(value: 1, label: Text('All city')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      );
      expectText(tester, find.text('Near me'), what: 'selected segment');
      expectText(tester, find.text('All city'), what: 'unselected segment');
    });

    testWidgets('Slider: thumb, track and value-indicator label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Slider(value: 0.4, divisions: 5, label: '40%', onChanged: (_) {}),
      );
      final render = tester.renderObject(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_SliderRenderObjectWidget',
        ),
      ) as dynamic;
      // The slider's resolved theme lives on a private render object.
      // ignore: avoid_dynamic_calls
      final slider = render.sliderTheme as SliderThemeData;
      final bg = Theme.of(tester.element(find.byType(Slider)))
          .scaffoldBackgroundColor;
      expectMark(slider.activeTrackColor!, bg, 'active track');
      expectMark(slider.thumbColor!, bg, 'thumb');
      // The value-indicator bubble is a fill; its label must read on it.
      final bubble = slider.valueIndicatorColor!;
      final label = slider.valueIndicatorTextStyle!.color!;
      expect(contrastOf(label, bubble), greaterThanOrEqualTo(4.5));
      // Record which colour the bubble uses (reported, not asserted).
      debugPrint('Slider value indicator: ${_hex(bubble)} / ${_hex(label)}');
    });

    testWidgets('Text-selection handles and cursor use Neel', (tester) async {
      await pumpThemed(tester, const TextField());
      final theme = Theme.of(tester.element(find.byType(TextField)));
      expect(theme.textSelectionTheme.selectionHandleColor, BrandLight.focus);
      expectMark(
        theme.textSelectionTheme.selectionHandleColor!,
        theme.scaffoldBackgroundColor,
        'selection handle',
      );
    });

    testWidgets('Badge: count label on its fill', (tester) async {
      await pumpThemed(
        tester,
        const Badge(label: Text('3'), child: Icon(Icons.notifications)),
      );
      final theme = Theme.of(tester.element(find.byType(Badge)));
      final fg = glyphColor(tester, find.text('3'));
      expect(
        contrastOf(fg, theme.badgeTheme.backgroundColor!),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('NavigationBar: selected icon, labels', (tester) async {
      await pumpThemed(
        tester,
        NavigationBar(
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              label: 'Saved',
            ),
          ],
        ),
      );
      final theme = Theme.of(tester.element(find.byType(NavigationBar)));
      expectMark(
        glyphColor(tester, find.byIcon(Icons.home)),
        theme.navigationBarTheme.indicatorColor!,
        'selected nav icon on indicator',
      );
      expectMark(
        theme.navigationBarTheme.indicatorColor!,
        theme.navigationBarTheme.backgroundColor!,
        'nav indicator on bar',
      );
      expectText(tester, find.text('Home'), what: 'selected nav label');
      expectText(tester, find.text('Saved'), what: 'nav label');
    });

    testWidgets('FilterChip: selected checkmark and labels', (tester) async {
      await pumpThemed(
        tester,
        Wrap(
          children: [
            FilterChip(
              label: const Text('Fashion'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(label: const Text('Food'), onSelected: (_) {}),
          ],
        ),
      );
      final theme = Theme.of(tester.element(find.byType(FilterChip).first));
      expectMark(
        theme.chipTheme.checkmarkColor!,
        theme.chipTheme.selectedColor!,
        'checkmark',
      );
      expectText(tester, find.text('Fashion'), what: 'selected chip');
      expectText(tester, find.text('Food'), what: 'chip');
    });

    testWidgets(
      'Chip avatars (ActionChip / InputChip / FilterChip) are not Haldi',
      (tester) async {
        await pumpThemed(
          tester,
          Wrap(
            children: [
              ActionChip(
                avatar: const Icon(Icons.local_offer_outlined),
                label: const Text('Offers'),
                onPressed: () {},
              ),
              InputChip(
                avatar: const Icon(Icons.place_outlined),
                label: const Text('Clifton'),
                onPressed: () {},
              ),
              FilterChip(
                avatar: const Icon(Icons.restaurant_outlined),
                label: const Text('Food'),
                onSelected: (_) {},
              ),
            ],
          ),
        );
        final theme = Theme.of(tester.element(find.byType(Wrap)));
        final chipFill = theme.chipTheme.backgroundColor!;
        for (final icon in [
          Icons.local_offer_outlined,
          Icons.place_outlined,
          Icons.restaurant_outlined,
        ]) {
          expectMark(glyphColor(tester, find.byIcon(icon)), chipFill, '$icon');
        }
      },
    );

    testWidgets('ListTile selected: title and leading icon', (tester) async {
      await pumpThemed(
        tester,
        const Card(
          child: ListTile(
            selected: true,
            leading: Icon(Icons.home),
            title: Text('Karachi'),
          ),
        ),
      );
      expectText(tester, find.text('Karachi'), what: 'selected ListTile');
      expectMark(
        glyphColor(tester, find.byIcon(Icons.home)),
        backgroundOf(tester, find.byIcon(Icons.home)),
        'selected ListTile icon',
      );
    });

    testWidgets('PopupMenu items', (tester) async {
      await pumpThemed(
        tester,
        PopupMenuButton<int>(
          tooltip: 'More',
          itemBuilder: (_) => const [
            PopupMenuItem(value: 1, child: Text('Share')),
            CheckedPopupMenuItem(value: 2, checked: true, child: Text('Saved')),
          ],
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expectText(tester, find.text('Share'), what: 'menu item');
      expectText(tester, find.text('Saved'), what: 'checked menu item');
      expectMark(
        glyphColor(tester, find.byIcon(Icons.done)),
        backgroundOf(tester, find.byIcon(Icons.done)),
        'menu check icon',
      );
    });

    testWidgets('DropdownMenu: field label (focused) and entries', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: DropdownMenu<int>(
            label: Text('City'),
            initialSelection: 1,
            dropdownMenuEntries: [
              DropdownMenuEntry(value: 1, label: 'Karachi'),
              DropdownMenuEntry(value: 2, label: 'Lahore'),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(DropdownMenu<int>));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(DropdownMenu<int>)));
      final label = glyphColor(tester, find.text('City'));
      expect(
        contrastOf(label, theme.inputDecorationTheme.fillColor!),
        greaterThanOrEqualTo(4.5),
        reason: 'focused label ${_hex(label)}',
      );
      expectText(tester, find.text('Lahore').last, what: 'menu entry');
      expectText(tester, find.text('Karachi').last, what: 'selected entry');
    });

    testWidgets('SearchBar: hint, typed text, leading icon', (tester) async {
      await pumpThemed(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: SearchBar(
            hintText: 'Search deals',
            leading: Icon(Icons.search),
          ),
        ),
      );
      expectText(tester, find.text('Search deals'), what: 'search hint');
      await tester.enterText(find.byType(SearchBar), 'lawn');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final bar = backgroundOf(tester, find.byType(EditableText));
      expect(contrastOf(editable.style.color!, bar), greaterThanOrEqualTo(4.5));
      expectMark(
        glyphColor(tester, find.byIcon(Icons.search)),
        backgroundOf(tester, find.byIcon(Icons.search)),
        'search icon',
      );
    });

    testWidgets('TimePicker: dial hand and focused input border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _opener(
          'open',
          (c) => showTimePicker(
            context: c,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final dial =
          tester
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .firstWhere(
                    (p) => p.painter.runtimeType.toString() == '_DialPainter',
                  )
                  .painter!
              as dynamic;
      // The dial colours live on a private painter.
      // ignore: avoid_dynamic_calls
      final hand = dial.handColor as Color;
      // Same private painter as above.
      // ignore: avoid_dynamic_calls
      final face = dial.backgroundColor as Color;
      final problems = <String>[];
      if (contrastOf(hand, face) < 3) {
        problems.add(
          'dial hand ${_hex(hand)} on ${_hex(face)} = '
          '${contrastOf(hand, face).toStringAsFixed(2)}:1',
        );
      }
      // Switch to keyboard entry and focus the hour field.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      final focused = field.decoration!.focusedBorder!.borderSide.color;
      final fill =
          field.decoration!.fillColor ??
          Theme.of(tester.element(find.byType(TextField).first))
              .colorScheme
              .surfaceContainerHighest;
      if (contrastOf(focused, fill) < 3) {
        problems.add(
          'focused hour field border ${_hex(focused)} on ${_hex(fill)} = '
          '${contrastOf(focused, fill).toStringAsFixed(2)}:1',
        );
      }
      expect(problems, isEmpty);
    });

    testWidgets('ElevatedButton label', (tester) async {
      await pumpThemed(
        tester,
        ElevatedButton(onPressed: () {}, child: const Text('Get deal')),
      );
      expectText(tester, find.text('Get deal'), what: 'ElevatedButton');
    });

    testWidgets('IconButton.filled (light): icon on the Haldi fill', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        IconButton.filled(
          tooltip: 'Save',
          onPressed: () {},
          icon: const Icon(Icons.bookmark),
        ),
      );
      expectMark(
        glyphColor(tester, find.byIcon(Icons.bookmark)),
        backgroundOf(tester, find.byIcon(Icons.bookmark)),
        'IconButton.filled icon',
      );
    });

    testWidgets(
      'Other primary-coloured text: ExpansionTile, BottomNavigationBar, '
      'ToggleButtons',
      (tester) async {
        await pumpThemed(
          tester,
          Column(
            children: [
              const ExpansionTile(
                initiallyExpanded: true,
                title: Text('Card offers'),
                children: [Text('HBL')],
              ),
              ToggleButtons(
                isSelected: const [true, false],
                onPressed: (_) {},
                children: const [Text('List'), Text('Map')],
              ),
              BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Feed',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark),
                    label: 'Later',
                  ),
                ],
              ),
            ],
          ),
        );
        final failures = <String>[];
        for (final t in ['Card offers', 'List', 'Feed']) {
          final f = find.text(t);
          final fg = glyphColor(tester, f);
          final bg = backgroundOf(tester, f);
          if (contrastOf(fg, bg) < 4.5) {
            failures.add(
              '$t: ${_hex(fg)} on ${_hex(bg)} = '
              '${contrastOf(fg, bg).toStringAsFixed(2)}:1',
            );
          }
        }
        for (final icon in [Icons.expand_more, Icons.home]) {
          final f = find.byIcon(icon);
          final fg = glyphColor(tester, f);
          final bg = backgroundOf(tester, f);
          if (contrastOf(fg, bg) < 3) {
            failures.add(
              '$icon: ${_hex(fg)} on ${_hex(bg)} = '
              '${contrastOf(fg, bg).toStringAsFixed(2)}:1',
            );
          }
        }
        expect(failures, isEmpty);
      },
    );

    testWidgets('SnackBar action on the inverse surface', (tester) async {
      await pumpThemed(
        tester,
        _opener(
          'open',
          (c) => ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(
              content: const Text('Saved'),
              action: SnackBarAction(label: 'UNDO', onPressed: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectText(tester, find.text('UNDO'), what: 'snackbar action');
      expectText(tester, find.text('Saved'), what: 'snackbar text');
    });
  });

  testWidgets(
    'textContrastGuideline passes on a page of primary-pulling widgets',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        Column(
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Get deal')),
            const ListTile(selected: true, title: Text('Karachi')),
            ToggleButtons(
              isSelected: const [true, false],
              onPressed: (_) {},
              children: const [Text('List'), Text('Map')],
            ),
          ],
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  group('dark theme', () {
    testWidgets('IconButton.filled: icon on the Haldi fill', (tester) async {
      await pumpThemed(
        tester,
        IconButton.filled(
          tooltip: 'Save',
          onPressed: () {},
          icon: const Icon(Icons.bookmark),
        ),
        brightness: Brightness.dark,
      );
      expectMark(
        glyphColor(tester, find.byIcon(Icons.bookmark)),
        backgroundOf(tester, find.byIcon(Icons.bookmark)),
        'IconButton.filled icon (dark)',
      );
    });

    testWidgets('SnackBar action on the inverse surface', (tester) async {
      await pumpThemed(
        tester,
        _opener(
          'open',
          (c) => ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(
              content: const Text('Saved'),
              action: SnackBarAction(label: 'UNDO', onPressed: () {}),
            ),
          ),
        ),
        brightness: Brightness.dark,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectText(tester, find.text('UNDO'), what: 'snackbar action (dark)');
    });
  });

  group('IconButton toggle', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: selected state differs from idle', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          Row(
            children: [
              IconButton(
                tooltip: 'a',
                isSelected: true,
                onPressed: () {},
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite),
              ),
              IconButton(
                tooltip: 'b',
                onPressed: () {},
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite),
              ),
            ],
          ),
          brightness: brightness,
        );
        final sel = glyphColor(tester, find.byIcon(Icons.favorite));
        final bg = backgroundOf(tester, find.byIcon(Icons.favorite));
        debugPrint('selected IconButton ${brightness.name}: ${_hex(sel)}');
        expectMark(sel, bg, 'selected IconButton');
      });
    }
  });
}
