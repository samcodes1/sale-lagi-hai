---
name: flutter-ui-ux
description: Mobile UI/UX playbook for the Sale Lagi Hai! Flutter app. Covers Material 3 theming from the brand tokens, layout, touch targets, text scaling, accessibility, RTL/Urdu (Nastaliq), motion, loading/empty/error/offline states, onboarding and permission priming, notification UX, deal-card patterns, search/filter and dark mode. Use it when designing, building or reviewing any screen or widget.
---

# Flutter UI/UX playbook: Sale Lagi Hai!

**Inputs to read first:** `design/tokens/brand_tokens.json` (the palette is Haldi, Neel, Mirch and Surma), `design/flutter/brand_tokens.dart`, `design/tokens/contrast-report.md`, `design/fonts/`, and `docs/ux/UX_ARCHITECTURE.md` (screens, flows, notification taxonomy).

**Deep detail:** [references/theming.md](references/theming.md) (ThemeData, type scale, spacing and motion tokens) · [references/rtl-urdu.md](references/rtl-urdu.md) · [references/deal-patterns.md](references/deal-patterns.md) (deal cards, badges, search and filter) · [references/ux-review-checklist.md](references/ux-review-checklist.md)

## 0. Platform facts that changed in 2026 (check before you build)
- **Material is now a package.** In Flutter 3.47, `package:flutter/material.dart` was published as the standalone **`material_ui`** package (Cupertino became `cupertino_ui`). The in-SDK copy is frozen and is scheduled for deprecation in the November stable release.
  - New code imports `package:material_ui/material_ui.dart`. To migrate, run `dart fix --apply --code=migrate_design_widgets`, then `flutter pub add material_ui`.
  - Use `localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]`. This includes the Cupertino and Widgets delegates.
  - Wrap the app in `MaterialUiCompatibilityBridge` inside `MaterialApp.builder` while some dependencies still import the old library. go_router 18, google_fonts 9, shimmer 4 and cached_network_image 4 already use material_ui; alchemist and skeletonizer don't yet.
  - The bridge is itself `@Deprecated` (a temporary utility), so `flutter analyze` reports `deprecated_member_use`. Add a one-line `// ignore:` with a reason and a TODO to remove it once all dependencies have migrated.
  - The bridge cannot fix *type* mismatches, such as passing a material_ui `ThemeData` into an API typed against the old `ThemeData`. alchemist's own `MaterialApp` is the old library, so material_ui widgets in goldens need a host wrapper (see the qa-testing skill; verified locally).
- **Material 3 Expressive** (`StyleVariant.material3Expressive`) is marked "under development" in material_ui 1.8. Don't opt in for production. Stay on `StyleVariant.material3`.
- **Edge-to-edge** is mandatory on Android 16 and you cannot opt out. We target API 36, which Play requires for new apps and updates from 31 Aug 2026.
  - Lay out under the system bars and use `SafeArea` or `MediaQuery.paddingOf`. Never hard-code the status bar height.
  - The bottom nav and FABs must clear the gesture bar.
- **Predictive back** (Android 14+): use `PopScope(canPop: …, onPopInvokedWithResult: …)`. `WillPopScope` is deprecated. Decide ahead of time whether back is allowed, because the system can't ask you during the gesture.
- **Web accessibility (3.44+):** Flutter web honours `prefers-reduced-motion` automatically, and form-validation errors are announced to screen readers.

## 1. Theming (Material 3)
**Rules**
1. **The brand tokens are the source of truth.** Build `ColorScheme` explicitly from `brand_tokens.dart`. Don't let `ColorScheme.fromSeed` invent the brand colours.
   - Use `fromSeed(dynamicSchemeVariant: DynamicSchemeVariant.fidelity)` only to fill roles the tokens don't define. `fidelity` keeps the seed's chroma, while the default `tonalSpot` washes Haldi yellow into pastel.
2. **No dynamic colour (Material You).** It would change the brand. Keep `useMaterial3: true` (it's the default).
3. **Widgets read roles, never hex values.** Use `Theme.of(context).colorScheme.primary`.
   - Deal, featured, success, warning and info colours go in a `ThemeExtension<DealColors>` with a `lerp` so theme switches animate.
4. **Style through component themes, not per widget.** Set `filledButtonTheme`, `cardTheme`, `chipTheme`, `inputDecorationTheme`, `navigationBarTheme`, `snackBarTheme`, `bottomSheetTheme`, `badgeTheme`, `progressIndicatorTheme` and `appBarTheme`. A widget that hand-styles itself is a review finding.
5. **Ship light, dark and high-contrast schemes.** `MaterialApp` has `highContrastTheme` and `highContrastDarkTheme`. Android's high-contrast setting is detected automatically (`MediaQuery.highContrastOf`) since 3.47.
6. **Use the surface container roles for elevation.** Use `surfaceContainerLowest…Highest` instead of shadows. `background`, `onBackground` and `surfaceVariant` are deprecated; use `surface`, `onSurface` and `surfaceContainerHighest`.
7. **Watch the contrast budget of the Mirch deal red.** `#DC2E24` on white is **4.71:1**, which barely passes for normal text. Use it for badge fills with white bold labels, and never for small coloured text on tinted cards. Use `onDealContainer` on `dealContainer` (7.96:1) instead.

```dart
ThemeData buildTheme(Brightness b, {bool highContrast = false}) {
  final t = b == Brightness.light ? BrandTokens.light : BrandTokens.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: t.primary, onPrimary: t.onPrimary,                 // Haldi
    primaryContainer: t.primaryContainer, onPrimaryContainer: t.onPrimaryContainer,
    secondary: t.secondary, onSecondary: t.onSecondary,         // Neel
    error: t.error, onError: t.onError,
    surface: t.surface, onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary, outline: t.outlineStrong,
    surfaceContainerHighest: t.surfaceVariant,
    // …the remaining roles come from the tokens, see references/theming.md
  );
  return ThemeData(
    colorScheme: scheme,
    textTheme: AppTypography.textTheme(scheme),                 // bundled fonts
    extensions: [DealColors.from(t)],
    visualDensity: VisualDensity.standard,                      // keep 48dp targets
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
```

## 2. Typography and text scaling
- Use the **M3 type scale** roles: display, headline, title, body, label × L/M/S. Body Large is 16sp and Label Small is 11sp (see references/theming.md).
  - Our minimum is 12sp for any informative text. 11sp is allowed only for decorative or duplicated labels.
- **Fonts are bundled offline. Never fetch fonts at runtime.**
  - Latin: Instrument Sans for UI and body, Bricolage Grotesque for display and headlines.
  - Urdu: **Noto Nastaliq Urdu** for headings, prices and short Urdu copy; **Noto Naskh Arabic** for dense UI text, chips and inputs where Nastaliq height breaks layouts.
  - Set `fontFamilyFallback` so mixed Latin and Urdu strings render. On the web, a missing glyph triggers a download of fallback Noto fonts from Google's CDN, which bundling avoids.
- **Respect the user's text size.** Read it with `MediaQuery.textScalerOf(context)`. Don't use the deprecated `textScaleFactor`, and never clamp below 2.0×.
  - Every screen must work at **200%** (WCAG 1.4.4) on a 360×800 screen.
  - Android 14+ scales text **non-linearly** (large text grows less), so test with the real `TextScaler` and not by multiplying font sizes.
- If scaling breaks something, fix the layout: wrap, scroll, allow 2–3 lines with `maxLines` + ellipsis on titles, or stack a row into a column at large scales. Never fix it by shrinking text.
- Use `Text.rich` with semantic spans for prices, such as ~~Rs 2,999~~ **Rs 1,799**. The strikethrough is invisible to screen readers, so add a `semanticsLabel` ("was Rs 2,999, now Rs 1,799").

## 3. Layout, spacing and responsiveness
- **The grid is 4dp, with 8dp rhythm** for main spacing. Tokens: `space4, 8, 12, 16, 24, 32, 48`. Screen side padding is 16dp on compact screens and 24dp on medium.
- **Size from the window, not the device.** Use `MediaQuery.sizeOf(context)` (it rebuilds less than `MediaQuery.of`) or `LayoutBuilder` for local constraints. Never branch on device type or orientation.
- **Breakpoints (M3 window classes):**

| Class | Width | Layout |
|---|---|---|
| Compact | < 600dp | One column, bottom `NavigationBar` |
| Medium | 600–839 | Two-column grid, `NavigationRail` |
| Expanded | ≥ 840 | Rail or drawer plus list-detail. The business and admin portals live here |

- Don't lock orientation. The Flutter docs advise against it, and Android large-screen compatibility mode can override a lock anyway.
- Lists use **slivers** (`CustomScrollView`, `SliverList.builder`). Never use `ListView(children: [...])` for feeds, and always give `itemExtent` or `prototypeItem` when rows have a fixed height.
- Use **directional** geometry everywhere: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, and `start`/`end` (see §6).

## 4. Touch targets
- **48×48dp minimum** for anything tappable (Android and Material). iOS asks for 44pt, and WCAG 2.5.8 asks for 24×24 CSS px as the AA floor; we use 48 everywhere.
  - Keep at least 8dp between adjacent targets.
  - Small visual icons such as save, share or close stay 24dp visually but get a 48dp hit area: `IconButton` (default), `InkResponse` + `SizedBox`, or `MaterialTapTargetSize.padded`.
- The whole deal card is one primary target that opens the deal. Secondary actions (save, share) are separate 48dp targets and must not overlap the card's tap area.
- Never require dragging. Every swipe action (swipe to dismiss, carousel) needs a button alternative (WCAG 2.5.7).
- Test with `meetsGuideline(androidTapTargetGuideline)` and `labeledTapTargetGuideline` (see the qa-testing skill).

## 5. Accessibility (TalkBack first)
1. **Every interactive element has a label.** Give `IconButton`s a `tooltip:`, which doubles as the label. Use `Semantics(label:, button: true)` for custom tappables, and in Urdu the label is in Urdu.
2. **Merge composite widgets.** A deal card reads as one sentence. Wrap it in `MergeSemantics`, exclude decoration with `ExcludeSemantics`, and give images `semanticLabel` or `excludeFromSemantics: true`.
   - The card's label order is: brand → offer → price → expiry → "Featured" if sponsored.
3. **Mark headings** with `Semantics(header: true, headingLevel: n)` on section titles such as "Trending in Karachi". TalkBack users navigate by heading.
4. **Announce state changes without moving focus.**
   - Use `Semantics(liveRegion: true)` on banners and snackbars, for example "Saved" or "You're offline" (WCAG 4.1.3).
   - Use `SemanticsService.sendAnnouncement(View.of(context), msg, dir)` only when there's no widget to attach to. `announce` is deprecated, and Android discourages announcement events.
5. **Never use colour alone** (WCAG 1.4.1). "Expired" needs text or an icon as well as grey, "ending soon" needs a clock icon and text, and errors need an icon and a message.
6. **Contrast:** text needs 4.5:1, large text (≥18pt, or ≥14pt bold) needs 3:1, and UI parts and focus rings need 3:1 (WCAG 1.4.3 and 1.4.11). Text on deal images sits on a scrim, and you test the worst case.
7. **Reduce motion:** when `MediaQuery.disableAnimationsOf(context)` is true, drop parallax, auto-advancing carousels, shimmer sweeps and countdown "pulse". Replace them with instant or fade changes.
8. **Also honour** `boldTextOf`, `highContrastOf` and `invertColorsOf`, and check `supportsAnnounceOf` before announcing.
9. **Focus order follows reading order**, which is mirrored in RTL. Use `FocusTraversalGroup` with `OrderedTraversalPolicy` only when the visual order truly differs. Keyboard focus must never be hidden under a sticky bar (WCAG 2.4.11); this matters for the web portals.
10. **Auto-moving content** (carousels, tickers) must have pause, stop or hide (WCAG 2.2.2). Default: carousels don't auto-advance.
11. **Accessible sign-in** (WCAG 3.3.8): phone OTP allows paste and `AutofillHints.oneTimeCode`, and there's no CAPTCHA puzzle.
12. **Test manually.** Run TalkBack through the five main flows each phase, use Android Accessibility Scanner, and on the web visualise semantics with `--dart-define=FLUTTER_WEB_DEBUG_SHOW_SEMANTICS=true`.

## 6. RTL and Urdu (summary; see references/rtl-urdu.md)
- Flutter mirrors layout automatically when the locale is `ur` (through `GlobalWidgetsLocalizations`). **Never wrap screens in `Directionality(textDirection: TextDirection.ltr)`** to "fix" a layout.
- Use `start`/`end` everywhere. `left`/`right`, `EdgeInsets.only(left:)` and `Alignment.centerLeft` are review findings unless they refer to a physical direction.
- **Flip** directional icons such as back, forward, chevrons, "next" and send. Built-in `Icons.arrow_back` adapts; for custom icons use `Icon(..., matchTextDirection: true)`.
  - **Don't flip** logos, the checkmark, clocks, play/pause, media controls, photos, or numbers and their digit order.
  - Do mirror sliders and progress bars.
- **Nastaliq is tall.** Its ascenders and descenders overflow normal line boxes. Give Nastaliq styles `height: 1.6–1.9` with a matching `StrutStyle`, leave padding for descenders, and never clip it with fixed-height containers or `ClipRect`. Test every chip, button and badge in Urdu.
- **Mixed direction:** isolate user or brand content inside sentences with Unicode FSI/PDI (`⁨…⁩`). Phone numbers, promo codes and URLs are wrapped as LTR isolates.
- **Roman Urdu is LTR Latin text.** It lives in the `en` copy, not in `ur`.
- Since 3.47, `WidgetSpan` inline widgets follow bidi visual order. Remove any RTL "swap" workarounds and regenerate RTL goldens.

## 7. Motion
- Use the M3 tokens (Flutter `Durations` and `Easing`):
  - Micro-feedback: `short2–short4` (100–200ms).
  - Component enter and exit: `medium2–medium4` (300–400ms) with `Easing.emphasizedDecelerate` in and `emphasizedAccelerate` out.
  - Full-screen transitions: `long2` (500ms).
- Motion has a purpose: continuity (a card expanding into the deal detail with a container transform), feedback (save → heart fill), or attention (a new-deal pill). Don't animate frequent interactions, and never make people wait for an animation.
- Honour reduce motion (§5.7). Countdowns update their text and don't animate digits. Shimmer becomes a static placeholder.
- Use the platform page transitions. On Android that's `FadeForwardsPageTransitionsBuilder`, which material_ui 1.8 made 20–40% cheaper to render. Keep predictive back working.

## 8. Loading, empty, error and offline states (every screen has all four)
| State | Pattern | Rules |
|---|---|---|
| Loading under 1s | Nothing, or keep the previous content | Don't flash a skeleton for fast loads |
| Loading 1–10s | **Skeleton** with the shape of the real layout (skeletonizer or a static placeholder) | One skeleton system. Use the real card size so nothing jumps. The semantics label is "Loading deals" |
| Long or determinate | `LinearProgressIndicator` with a value | For uploads and image processing in the business portal |
| Empty | Illustration (decorative) + one sentence + **one action** | "No deals in Gulberg yet. Follow brands to get alerts." with a [Follow brands] button. Different copy for "no results for filters" ([Clear filters]) |
| Error | What happened + what to do + [Retry] | Plain language with no codes. Keep cached content visible with an inline banner instead of a full-screen error |
| Offline | A persistent, non-blocking banner (live region) + cached content + "Updated 2h ago" | Queue saves and reports offline. Disable actions that need the network, and say why |

- **Pull to refresh:** `RefreshIndicator.adaptive` on every feed. Refreshing keeps the scroll position and shows a "New deals" pill when new items arrive above.
- **Infinite scroll:** cursor (keyset) pagination. Prefetch when about 5 items from the end, show a footer loader, and an inline footer [Retry] on error (never a full-screen error).
  - Show an end-of-list message ("You've seen all deals in Food. Explore other categories").
  - Keep a "back to top" affordance after about 3 screens of scrolling.
- **Optimistic UI** for save, follow and like, rolled back with a snackbar on failure.

## 9. Onboarding and permission priming
- **Language choice is the only required step.** Show "English / اردو" as large tiles on the first screen and default from the device locale. Everything else can be skipped, and the target is first launch in under 60 seconds (UX flow F1).
- Teach by doing: pick city → pick 3+ categories → see the feed. No carousel of feature slides, and no sign-in wall. Sign-in is optional and asked only when a feature needs it (sync, submit a deal).
- **Never ask for a permission at launch.** Ask in context, after a priming screen we control:
  1. **Notifications** (Android 13+ `POST_NOTIFICATIONS`): trigger when the user taps "Alert me" on a brand or category, or after they follow something.
     - The priming sheet shows an example alert, the frequency promise ("At most 3 a day, never at night") and the topics, with [Turn on alerts] and [Not now].
     - Call the system dialog only after [Turn on alerts].
     - New installs on Android 13+ start with notifications **off** until granted. If denied, show an in-app banner in the Alerts tab that deep-links to settings (`openAppNotificationSettings()` in flutter_local_notifications 22.3+). Never re-prompt in a loop.
  2. **Location:** trigger on "Deals near me". Request **approximate** (`ACCESS_COARSE_LOCATION`) first; the app must fully work with approximate (~3 km²). Ask for precise only for "nearest outlet" distance sorting.
     - Never request background location. We don't need it, and Play restricts it.
     - Always offer manual city or area selection as the alternative.
     - Apps targeting Android 17+ whose location features are only session-based must use the system **location button**. Plan for it.
- When `shouldShowRequestPermissionRationale` is true, show our rationale again before re-requesting. After a permanent denial, switch to a settings deep-link.
- Ask for ratings (`in_app_review`) only after a success moment, such as using a deal, and never during onboarding.

## 10. Notification UX
- **The user controls topics per item**: followed brands, categories, my bank cards, my city, and price drops on saved deals. Each has a toggle in Alerts settings, and each maps to one Android **notification channel** so users can also mute it from system settings.
- **Frequency caps are enforced server-side** in the dispatcher Edge Function:
  - At most 3 marketing or deal pushes per user per day, and at most 1 per brand per day.
  - Collapse duplicates with a collapse key and group them (for example "5 new Food deals").
  - The user can pick Low (1 a day), Normal (3) or High (6).
- **Quiet hours** default to 22:00–08:00 Asia/Karachi and are user-editable. Respect Ramadan and Jumu'ah timing in campaigns, and never send pushes at Sehri.
  - Deliveries that would land in quiet hours are deferred to the morning digest, not dropped.
- **Content:** a specific title ("Khaadi: up to 50% off, ends Sunday") and a body with the useful detail. Don't put the app name in the title, and never send "Open the app to see…".
  - No sensitive data in the payload, such as card numbers or a phone number.
  - Sponsored pushes say "Featured" or "Sponsored" in the body.
- **Tapping a notification deep-links to that exact deal**, with a valid back stack (Home → Deal). If the deal has expired, show the deal with an "Expired" state and similar live deals, never a 404.
- In the foreground, don't show a system notification. Show an in-app banner or a badge increment.
- Badges only count unread alerts. Clear them when the Alerts tab is opened.

## 11. Deal and e-commerce patterns (summary; see references/deal-patterns.md)
- **Card content priority:** image → brand → offer headline ("Flat 30% off") → price (new + struck old) → discount badge → expiry → freshness. Bank and card offers add a card-network chip.
- **Discount badge:** one style (Mirch fill, white bold label) showing the *real* computed number ("-40%"). Never show "Up to" without the word, and never fake a discount.
- **Expiry:**
  - Over 72h: show the date ("Ends 3 Nov").
  - Under 72h: show relative time ("Ends in 2 days").
  - Under 24h: live countdown "Ends in 05:12:33", updated once per second only while visible. The semantics label stays coarse ("Ends in 5 hours") so TalkBack doesn't chatter.
  - Expired: greyed with an "Expired" chip, and sorted out of feeds.
- **Trust signals:** "Verified 3 hours ago" (with source and checker type: "by our team" or "from brand's website"), a "Reported expired by N users" warning, an official brand badge, and the bank's T&Cs one tap away.
- **Sponsored content is always labelled.** Use a visible "Featured" chip in Haldi with a text label (not an icon only) on the card, in the semantics label, and in pushes. Featured deals never look different in what they promise, and never more than 1 in every 5 feed items.

## 12. Search and filter (summary)
- Search is always one tap from Home. It shows recent searches, trending searches and category shortcuts before typing. Debounce queries by 300ms.
- It tolerates Roman Urdu and typos (server-side trigram search) and shows "Did you mean".
- Filters (city/area, category, bank card, discount ≥, ends within, distance) open in a bottom sheet with a live result count on the [Show 128 deals] button. Active filters show as removable chips above results, with [Clear all].
- Sort options: Relevance (default), Newest, Ending soon, Biggest discount, Nearest (only if location is granted).

## 13. Dark mode
- Follow the system (`ThemeMode.system`) by default. An app-level override (System / Light / Dark) lives in Settings, because many Android users want it even though Apple's HIG advises against an app-only setting.
- Dark surfaces come from the Surma tokens (`#0F0B1F` background), not pure black. Raise elevation with lighter surface containers, not shadows.
- Re-check every colour pair in dark mode: the contrast report covers the tokens, and images need a slight dim. Haldi yellow is a fill colour; never use it for body text on dark backgrounds.
- Brand and partner logos on dark backgrounds sit on a light "plate" so they stay legible.

## 14. UX review checklist (short form; full list in references/ux-review-checklist.md)
- [ ] All four states (loading, empty, error, offline) are designed and implemented.
- [ ] The layout works at 360×800 and at 200% text with no overflow; Urdu Nastaliq isn't clipped.
- [ ] The RTL mirror is correct: chevrons flip, logos, digits and checkmarks don't, and `start`/`end` are used everywhere.
- [ ] Targets are ≥48dp and labelled, the TalkBack reading order is correct, and colour is never the only cue.
- [ ] Contrast passes in light, dark and high contrast; dark mode looks intentional.
- [ ] Reduce motion is honoured; no auto-advancing carousel.
- [ ] No permission prompt without in-context priming; the app works when permissions are denied.
- [ ] Sponsored items carry a visible "Featured" label in the UI, semantics and push.
- [ ] Expiry, freshness and the discount are real data and correctly formatted in both locales (PKR, dates).
- [ ] Copy is plain, specific and localized, and no raw error codes are shown.

## Sources
Page sources were read through their public GitHub mirrors where the docs host was blocked (marked †).
- docs.flutter.dev†: [Accessibility UI design](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing), [Assistive technologies](https://docs.flutter.dev/ui/accessibility/assistive-technologies), [Internationalization](https://docs.flutter.dev/ui/internationalization), [Adaptive best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices), [Adaptive general](https://docs.flutter.dev/ui/adaptive-responsive/general), [material_ui/cupertino_ui migration](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui), [WidgetSpan RTL bidi order](https://docs.flutter.dev/release/breaking-changes/widgetspan-rtl-bidi-order), [Edge-to-edge default](https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge), [Predictive back](https://docs.flutter.dev/release/breaking-changes/android-predictive-back)
- flutter.dev blog†: [What's new in Flutter 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47), [What's new in Flutter 3.44](https://flutter.dev/blog/whats-new-in-flutter-3-44)
- material_ui: [pub.dev](https://pub.dev/packages/material_ui), [CHANGELOG](https://github.com/flutter/packages/blob/main/packages/material_ui/CHANGELOG.md), [StyleVariant](https://pub.dev/documentation/material_ui/latest/material_ui/StyleVariant.html), [ColorScheme.fromSeed](https://pub.dev/documentation/material_ui/latest/material_ui/ColorScheme/ColorScheme.fromSeed.html), [DynamicSchemeVariant](https://pub.dev/documentation/material_ui/latest/material_ui/DynamicSchemeVariant.html)
- Material Design (Google's Material Components docs; m3.material.io itself was blocked): [Motion tokens](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md), [Type scale](https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md)
- Apple HIG: [Right to left](https://developer.apple.com/design/human-interface-guidelines/right-to-left), [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications), [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding), [Loading](https://developer.apple.com/design/human-interface-guidelines/loading), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- Android: [Notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission), [Location permissions](https://developer.android.com/training/location/permissions), [Target API requirement](https://developer.android.com/google/play/requirements/target-sdk)
- WCAG 2.2† (w3c/wcag source): [1.4.1 Use of Color](https://www.w3.org/TR/WCAG22/#use-of-color), [1.4.3](https://www.w3.org/TR/WCAG22/#contrast-minimum), [1.4.4](https://www.w3.org/TR/WCAG22/#resize-text), [1.4.10 Reflow](https://www.w3.org/TR/WCAG22/#reflow), [1.4.11](https://www.w3.org/TR/WCAG22/#non-text-contrast), [2.2.2](https://www.w3.org/TR/WCAG22/#pause-stop-hide), [2.3.3](https://www.w3.org/TR/WCAG22/#animation-from-interactions), [2.4.11](https://www.w3.org/TR/WCAG22/#focus-not-obscured-minimum), [2.5.7](https://www.w3.org/TR/WCAG22/#dragging-movements), [2.5.8](https://www.w3.org/TR/WCAG22/#target-size-minimum), [3.3.8](https://www.w3.org/TR/WCAG22/#accessible-authentication-minimum), [4.1.3](https://www.w3.org/TR/WCAG22/#status-messages)
- Flutter SDK 3.47.8 source (local): `MediaQuery.*Of` accessibility getters, the `SemanticsService.announce` deprecation, and the `flutter_test` guideline constants. intl 0.20.3 `ur` number symbols.
- [Noto Nastaliq Urdu metadata (google/fonts)](https://github.com/google/fonts/blob/main/ofl/notonastaliqurdu/METADATA.pb)
- Not reachable from this environment: m3.material.io, nngroup.com and lawsofux.com. The skeleton-under-10s and ~400ms feedback rules come from search snippets of [NN/g skeleton screens](https://www.nngroup.com/articles/skeleton-screens/) and Laws of UX (Doherty threshold). Verify them when those hosts are allowed.
