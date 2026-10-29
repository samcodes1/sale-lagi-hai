# RTL and Urdu reference

## 1. How direction works in Flutter
- `MaterialApp` with `supportedLocales: [Locale('en'), Locale('ur')]` and `GlobalMaterialLocalizations.delegates` (material_ui) sets `Directionality` to RTL for `ur` automatically. Read it with `Directionality.of(context)`.
- **Don't force direction at the screen level.** Force LTR only on *content* that is LTR by nature: phone numbers, promo codes, URLs, card BINs and code snippets. Use `Directionality(textDirection: TextDirection.ltr)` or `Text(..., textDirection: TextDirection.ltr)` for those.
- The language switch is in-app (Settings → Language). Store the choice and pass it to `MaterialApp.locale`. Since 3.38, `MaterialApp.locale` also selects the TalkBack voice.
- `TextSpan.locale` overrides the voice for a span. Use it for Urdu brand names inside English copy, and the reverse.

## 2. Directional APIs (use these, not the left/right versions)

| Instead of | Use |
|---|---|
| `EdgeInsets.only(left: 16)` / `fromLTRB` | `EdgeInsetsDirectional.only(start: 16)` / `fromSTEB` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `Positioned(left:)` | `PositionedDirectional(start:)` |
| `BorderRadius.only(topLeft:)` | `BorderRadiusDirectional.only(topStart:)` |
| `TextAlign.left` | `TextAlign.start` |
| `CrossAxisAlignment.start` in a Row | Already directional. Keep it |
| `Icon(Icons.chevron_right)` hard-coded | `Icons.chevron_right` with `matchTextDirection: true` on custom icons, or `Icons.adaptive.arrow_forward`. The built-in arrow and chevron icons flip automatically |
| `Transform.scale(scaleX: -1)` to mirror | Only for custom SVG icons that need flipping, and only when `Directionality.of(c) == TextDirection.rtl` |

A lint-like grep for reviews: `rg -n "EdgeInsets\.only\((left|right)|fromLTRB|Alignment\.(center|top|bottom)(Left|Right)|TextAlign\.(left|right)|Positioned\((left|right)" lib/`. Each hit needs a reason.

## 3. What to mirror (Apple HIG, Material bidirectionality)

| Mirror | Don't mirror |
|---|---|
| Back and forward arrows, chevrons, "next" and "previous" | Logos, brand marks, the app icon |
| Progress bars, sliders, rating bars (fill from the start edge) | Checkmark, plus, close (X), search magnifier |
| List-item trailing chevrons, swipe directions, page transitions | Clock and timer icons, play/pause/media controls |
| Send icon, "reply" arrow, undo/redo pairs (swap them) | Photos, product images, illustrations with real-world content |
| Icons that show text lines (align the bars right) | Numbers: digits in a number keep their order ("541", phone, card) |
| Order of images that encodes order (chronology) | Charts' time axis: keep LTR for consistency with numbers |
| Carousel and pager order, tab order, bottom nav order (Flutter does this) | A control that means a physical direction ("swipe right"), which must keep pointing that way |

Badges on cart or bell icons follow the UI mirror (top-start). When Latin all-caps text sits next to Urdu, increase the Urdu size by about 2pt so it looks balanced. That's an HIG tip, and it matters more for Nastaliq.

## 4. Urdu typography: Nastaliq pitfalls
Nastaliq has diagonal baselines and very tall ascenders and descenders. Typical failures:

1. **Clipped glyphs.** Fixed-height containers (`SizedBox(height: 20)` around text), `ClipRect`, `overflow: TextOverflow.clip` and tight `Chip` padding cut off dots and descenders.
   - **Fix:** let the text size itself, use `height: 1.7–1.9` with a strut, and add `padding: EdgeInsets.symmetric(vertical: 4)` extra on chips and badges.
2. **Line collisions in multi-line text.** Descenders of line 1 hit the ascenders of line 2.
   - **Fix:** a larger `height` plus `TextHeightBehavior(applyHeightToFirstAscent: true, applyHeightToLastDescent: true)` (the defaults) so the first and last lines also get room.
3. **Baseline misalignment** in `Row`s mixing an Urdu label and a Latin price or number.
   - **Fix:** `crossAxisAlignment: CrossAxisAlignment.baseline` + `textBaseline: TextBaseline.alphabetic`, or center the items and accept it; test both visually.
4. **Ellipsis on a single line** cuts words mid-ligature, and Urdu headlines get ~30% longer.
   - **Fix:** allow 2 lines for titles, and test the longest real strings (ARB placeholders filled with realistic Urdu).
5. **Size:** Nastaliq looks smaller at the same `fontSize`. Use a per-locale size multiplier (about 1.1–1.15) in the Urdu `TextTheme`. Never shrink it to fit.
6. **Performance:** Nastaliq shaping is heavier. Avoid animating Nastaliq text size, and cache long Urdu paragraphs in `RepaintBoundary` when scrolling.
7. **Dense UI** (chips, tabs, inputs, nav labels) may use **Noto Naskh Arabic** for Urdu, which is more compact. Readers accept it for UI, and Nastaliq stays for headlines and body. Confirm with brand-identity.

Starting values (tune them with goldens):

```dart
const nastaliq = TextStyle(fontFamily: 'NotoNastaliqUrdu', height: 1.8);
const nastaliqStrut = StrutStyle(fontFamily: 'NotoNastaliqUrdu', height: 1.8, leading: 0.2);
const naskh = TextStyle(fontFamily: 'NotoNaskhArabic', height: 1.55);
```

## 5. Mixed-direction text (bidi)
- The Unicode bidi algorithm handles most mixed strings. Problems come from **neutral characters** at the edges: %, -, (), punctuation, and digits next to Urdu.
  - Bad output example: "50%" rendering as "%50", or "Rs 1,799 -" with the dash on the wrong side.
- **Isolate inserted values** with First Strong Isolate (FSI, `⁨`) and Pop Directional Isolate (PDI, `⁩`), or use `intl`'s `BidiFormatter`:

```dart
String isolate(String s) => '⁨$s⁩';
// ARB: "dealTitle": "{brand} پر {pct} رعایت"  → pass isolate(brand), isolate('$pct%')
```

- Prefer a placeholder in the ARB message over string concatenation. Translators then control word order, and placeholders can be isolated in one place (a `formatPlaceholder` helper).
- Force these to LTR: phone numbers (+92 3xx xxxxxxx), promo codes, URLs, email addresses and card last-4. Use `textDirection: TextDirection.ltr` and `TextAlign.start` so they still align to the start edge in RTL.
- **Text fields:** set the `TextField` `textDirection` from the *content* for search boxes, because users type Roman Urdu (LTR) in Urdu UI. Flutter decides the direction per paragraph from the first strong character when `textDirection` is null in `TextField`. Verify on device.
- **Roman Urdu** ("Sale lagi hai! 50% off") is Latin script and LTR. It belongs in the English copy and is never stored as `ur` locale strings.

## 6. Numbers, currency, dates
- In `intl` 0.20.3, the `ur` locale uses **Western digits** (`ZERO_DIGIT: '0'`), grouping `#,##0`, and default currency PKR. The plan's "Urdu numerals as an option" therefore needs a digit-mapping step to Extended Arabic-Indic digits U+06F0–U+06F9 (۰۱۲۳۴۵۶۷۸۹), applied after formatting. Map only number spans, never IDs or promo codes.
- Show prices as `Rs 1,799` in en and `1,799 روپے` (or `Rs 1,799`, a brand decision) in ur. Use `NumberFormat.decimalPattern(locale)` and our own currency template. Don't trust `NumberFormat.simpleCurrency` to produce the local convention.
- **Lakh/crore grouping** (12,34,567) is common in Pakistan but is *not* what `intl`'s `ur` pattern produces. Decide it with brand and product. For prices under 1 lakh it doesn't matter.
- Dates: `DateFormat.MMMd(locale)` gives "3 Nov" in en and "3 نومبر" in ur. Relative time ("2 گھنٹے پہلے") comes from ARB plural messages, because `intl` has no relative formatter. Always compute in **Asia/Karachi** (UTC+5, no DST) for expiry. Store and transfer UTC.
- Plurals: Urdu needs the `one` and `other` forms. Always use ICU plural messages (`{count, plural, =0{…} one{…} other{…}}`), never `count == 1 ? … : …`.

## 7. Testing RTL
- **Widget and golden tests:** run each golden in `en`/LTR and `ur`/RTL × light/dark. Wrap with `Localizations` + `GlobalMaterialLocalizations.delegates` and `locale: Locale('ur')`. Load the real fonts in tests (`FontLoader`), or Nastaliq issues are invisible because the test font is Ahem.
- **Visual QA:** a Playwright `locale: 'ur-PK'` context on the web build (see the qa-testing skill).
- **Pseudo-RTL:** a debug-only "force RTL with English strings" toggle in the dev flavor catches hard-coded `left`/`right` quickly.
- **Checklist per screen:** chevrons flip; numbers and codes don't; Nastaliq isn't clipped at 200% text; the bottom nav order is mirrored; swipe directions match; and the focus and TalkBack order is right-to-left.

## Sources
- [Apple HIG: Right to left](https://developer.apple.com/design/human-interface-guidelines/right-to-left)
- [Flutter internationalization](https://docs.flutter.dev/ui/internationalization) and [WidgetSpan RTL bidi order](https://docs.flutter.dev/release/breaking-changes/widgetspan-rtl-bidi-order) (read through the flutter/website source)
- [Flutter assistive technologies (TextSpan.locale, MaterialApp.locale voices)](https://docs.flutter.dev/ui/accessibility/assistive-technologies)
- `intl` 0.20.3 `number_symbols_data.dart` (`ur` entry), read from the local pub cache
- [Noto Nastaliq Urdu metadata](https://github.com/google/fonts/blob/main/ofl/notonastaliqurdu/METADATA.pb) (OFL, variable `wght`)
