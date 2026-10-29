# Sale Lagi Hai! Brand guidelines v1.0

Strategy and voice: `BRAND_STRATEGY.md`. Concept history: `logo/CONCEPTS.md`. One-page board: `brand-board.png`.
Everything visual is generated from `design/_src/` (see "Regenerating" at the end). Never hand-edit generated files.

---

## 1. The logo

### Parts
| Asset | Files | Use |
|---|---|---|
| **Qalam Bang** (symbol) | `logo/svg/symbol-{ink,haldi,black,white}.svg` | Icons, favicons, stickers, watermark on share cards |
| **Symbol tile** (primary mark) | `logo/svg/symbol-tile.svg` (+ `-dark`, `-black`) | Social avatars, app-store contexts, anywhere a square is needed |
| **Wordmark** | `logo/svg/wordmark-*.svg` | App bar on splash/onboarding, marketing, partner materials |
| **Urdu wordmark** | `logo/svg/urdu-wordmark-*.svg` | Urdu-locale screens, Urdu marketing, shop stickers |
| **Bilingual lockup** | `logo/svg/lockup-bilingual-*.svg` | Shop-window stickers, posters, merchant kits |
| **Horizontal lockup** | `logo/svg/lockup-horizontal-{ink,on-dark,black,white}.svg` | Website header, decks, press |

PNG exports of each are in `logo/png/`.

**The idea in one line:** the shout, written properly. The exclamation mark is a Nastaliq alif (bar) and a nuqta
(dot) drawn with one reed-pen logic. Every "i" in the wordmark is dotted with the same nuqta.

### Construction notes
- Wordmark: Bricolage Grotesque ExtraBold, 75% width, 96 pt optical size, tracking −10/1000, converted to outlines.
  The i-dots are nuqtas (half-diagonal 9.2% of the type size); the closing bang is 80% of the type size tall
  (taller than the caps) and 1.2× wide to match the ExtraBold colour. Its nuqta overshoots the baseline by 1.6%.
- Urdu wordmark: Noto Nastaliq Urdu Bold shaped with HarfBuzz and outlined, then the Qalam Bang at the end of the
  RTL line (left), 70% of the lam height. The bang is **not** mirrored in RTL: an alif leans the same way in Urdu.

### Clear space
Unit **N** = the height of the nuqta in the artwork you are using (in the wordmark: the i-dot diamond).
- Wordmark and lockups: at least **2N** on every side.
- Symbol / tile: at least **25% of the tile width** on every side.
- Nothing (text, edges, other logos) enters that space.

### Minimum sizes
| Asset | Digital | Print |
|---|---|---|
| Symbol (bare bang) | 12 px tall (16 px icon) | 4 mm tall |
| Symbol tile | 20 px | 6 mm |
| English wordmark | 96 px wide | 25 mm wide |
| Urdu wordmark | 28 px tall (the nuqtas merge below this) | 8 mm tall |
| Horizontal lockup | 140 px wide | 35 mm wide |
| Bilingual lockup | 120 px wide | 30 mm wide |

Below the minimum, use the symbol alone.

### Color versions
| Background | Use |
|---|---|
| Kaghaz paper `#FFF8E7`, white, light photos | Ink (`#1A1433`) artwork |
| Surma ink `#1A1433`, dark photos | Haldi (`#FFC414`) or Kaghaz artwork |
| Haldi `#FFC414` | Ink artwork only |
| One-color print, emboss, engraving, fax, newspaper | Black or white versions |
| Mirch red `#DC2E24` | White artwork only, and only on deal/marketing material, never as the main brand background |

### Don'ts
1. Don't redraw, re-type or "fix" the wordmark in a live font. Use the outlined files.
2. Don't straighten, flip, mirror or rotate the bang. It leans right in English **and** Urdu.
3. Don't replace the diamond nuqta with a round dot, or the i-dots with round dots.
4. Don't add gradients, glows, bevels, 3D, outlines, drop shadows or sparkles. (Exception: the flat, hard
   `elevation.stamp` offset shadow on the tile, in marketing only.)
5. Don't add a second exclamation mark next to the logo ("Sale Lagi Hai!!").
6. Don't put the logo on busy photos without a solid panel; don't put ink on Mirch red.
7. Don't stretch, condense or add tracking.
8. Don't put "SALE", "%", prices or badges in the app icon (Google Play policy forbids deal promotions in icons).
9. Don't set the Urdu name in Naskh or in Roman Urdu as a substitute for the Urdu wordmark.
10. Don't combine the logo with truck-art ornaments, flags or crescents.

---

## 2. App icon

All files in `app-icon/` (SVG sources in `svg/`, PNGs in `png/`, ready Android resources in `android-res/`).

| Asset | File | Spec met |
|---|---|---|
| Play Store | `png/play-store-512.png` | 512×512, full-bleed square, no shadow, no rounding, no text |
| Adaptive foreground | `png/adaptive-foreground-432.png`, `android-res/drawable/ic_launcher_foreground.xml` | 108 dp canvas; mark 50 dp tall, max radius 27.2 dp (inside 33 dp safe-zone radius) |
| Adaptive background | `png/adaptive-background-432.png`, `drawable/ic_launcher_background.xml` | Solid Haldi |
| Monochrome (themed) | `png/adaptive-monochrome-432.png`, `drawable/ic_launcher_monochrome.xml` | Same mark at 92% (sits better on themed discs) |
| Adaptive XML | `android-res/mipmap-anydpi-v26/ic_launcher.xml` | background + foreground + monochrome |
| Legacy launcher | `png/legacy/ic_launcher{,_round}-<density>-<px>.png` | 48/72/96/144/192 px |
| Notification | `png/notification/ic_stat_sale-<density>-<px>.png`, `drawable/ic_stat_sale.xml` | White silhouette, 24 dp, mark 20.5 dp tall, optical-size bang (1.22× wider) |
| Notification accent | `android-res/values/brand_colors.xml` → `notification_accent` `#B78100` | `setColor()`; Haldi 700 so the white icon stays visible on the accent circle |
| Splash (Android 12+) | `png/splash-icon-{light,dark}-1152.png`, `drawable/splash_icon.xml` | 288 dp canvas without icon background; mark inside the 192 dp circle; window background Haldi (light) / Surma (dark) |
| Review | `preview-sheet.png`, `png/*safe-zone-guide*.png` | Home screens light/dark/themed, masks, 96→16 px, notification |

Alternate icon for the owner to consider: `png/play-store-512-alt-raat.png` (Haldi bang on ink, see §9).

For Flutter: the engineer can copy `android-res/` into `android/app/src/main/res/` (rename the PNG exports to
`mipmap-<density>/ic_launcher.png` for legacy), or feed `play-store-512.png` and the adaptive layers to
`flutter_launcher_icons`.

---

## 3. Color

Full tokens: `tokens/brand_tokens.json`; Flutter: `flutter/brand_tokens.dart`.

### Core
| Name | Hex | Role |
|---|---|---|
| **Haldi** (turmeric) | `#FFC414` | Brand. Primary buttons, the icon, the tile, Featured badge. A **fill** with ink content; never text on light. |
| **Surma** (kohl ink) | `#1A1433` | Text, the mark, dark-theme surface, selected-state indicators on light. |
| **Kaghaz** (paper) | `#FFF8E7` | Behind the logo, marketing paper. |
| **Neel** (truck-art blue) | `#3B3FD9` | Secondary: links, secondary buttons, selection, focus, info. |
| **Mirch** (chilli) | `#DC2E24` | Deal/hot accent: **discount badges only** ("-40%", "Ends tonight"). |

Ratio guide: ~80% neutrals, ~12% Surma, ~6% Haldi, ≤2% Mirch and Neel. Haldi is loud because it is rare.

### Scales
| Step | Haldi | Surma (neutral) | Neel | Mirch |
|---|---|---|---|---|
| 0 | | `#FFFFFF` | | |
| 50 | `#FFF8E1` | `#FAF8F4` | `#EEEFFF` | `#FFF0EE` |
| 100 | `#FFEDB3` | `#F2EFEA` | `#DCDDFF` | `#FFDAD5` |
| 200 | `#FFE07A` | `#E3DFD9` | `#BCBEFF` | `#FFB4AB` |
| 300 | `#FFD447` | `#CBC6C0` | `#9EA2FF` | `#FF8A7E` |
| 400 | `#FFCB2B` | `#A29DA6` | `#7378F2` | `#FF6B5E` |
| 500 | **`#FFC414`** | `#7B7585` | **`#3B3FD9`** | **`#DC2E24`** |
| 600 | `#E6A800` | `#5D5769` | `#2F32B8` | `#B8221A` |
| 700 | `#B78100` | `#433D50` | `#262894` | `#921A14` |
| 800 | `#8A5F00` | `#2C263A` | `#1D1F70` | `#6E130F` |
| 900 | `#5C3F00` | **`#1A1433`** | `#15164D` | `#4A0C09` |
| 950 | | `#0F0B1F` | | |

### Semantic
| | Light text/icon | Light container | Dark text/icon | Dark container |
|---|---|---|---|---|
| Success | `#18794E` | `#E6F6EC` | `#5FD39A` | `#0E3B27` |
| Warning | `#A34D00` | `#FFF1DC` | `#FFB547` | `#4A2600` |
| Error | `#B42318` | `#FEE4E2` | `#FF8F87` | `#55120C` |
| Info | `#3B3FD9` | `#EEEFFF` | `#9EA2FF` | `#1D1F70` |

Error (`#B42318`, crimson) and Mirch deal red (`#DC2E24`) are close in hue. They never appear without their shape
and words: errors always have an icon and a sentence; deals always show "-NN%" in a badge.

### Themes (role → color)
| Role | Light | Dark |
|---|---|---|
| background | `#FAF8F4` | `#0F0B1F` |
| surface | `#FFFFFF` | `#1A1433` |
| surfaceVariant | `#F2EFEA` | `#2C263A` |
| textPrimary | `#1A1433` | `#FAF8F4` |
| textSecondary | `#5D5769` | `#A29DA6` |
| outline / outlineStrong | `#E3DFD9` / `#7B7585` | `#433D50` / `#7B7585` |
| primary / onPrimary | `#FFC414` / `#1A1433` | `#FFC414` / `#1A1433` |
| secondary / onSecondary | `#3B3FD9` / `#FFFFFF` | `#9EA2FF` / `#15164D` |
| deal / onDeal | `#DC2E24` / `#FFFFFF` | `#FF6B5E` / `#0F0B1F` |
| indicator (selected tab, switch) | `#1A1433` | `#FFC414` |
| focus | `#3B3FD9` | `#9EA2FF` |

### Contrast check (WCAG 2.2, verified by script)
`design/_src/build_tokens.py` computes WCAG relative luminance for every pair and fails on any miss.
**64/64 pairs pass.** Highlights (full table: `tokens/contrast-report.md`):

| Pair | Ratio | Need | |
|---|---|---|---|
| Ink text on light background `#1A1433`/`#FAF8F4` | 16.61 | 4.5 | PASS |
| Secondary text `#5D5769`/`#FFFFFF` | 6.92 | 4.5 | PASS |
| Ink label on Haldi button `#1A1433`/`#FFC414` | 11.04 | 4.5 | PASS |
| Brand text Haldi 800 `#8A5F00`/`#FFFFFF` | 5.65 | 4.5 | PASS |
| Link Neel `#3B3FD9`/`#FFFFFF` | 7.24 | 4.5 | PASS |
| White on deal badge `#FFFFFF`/`#DC2E24` | 4.71 | 4.5 | PASS (tightest text pair) |
| Input border `#7B7585`/`#FFFFFF` | 4.44 | 3.0 | PASS |
| Success / warning / error text on white | 5.41 / 5.80 / 6.57 | 4.5 | PASS |
| Dark: text `#FAF8F4`/`#0F0B1F` | 18.20 | 4.5 | PASS |
| Dark: secondary text `#A29DA6`/`#1A1433` | 6.64 | 4.5 | PASS |
| Dark: deal badge `#0F0B1F`/`#FF6B5E` | 6.91 | 4.5 | PASS |
| Dark: input border `#7B7585`/`#1A1433` | 3.96 | 3.0 | PASS (tightest UI pair) |

Known limits: Haldi on white is 1.60:1, so Haldi is never text, an icon stroke, a border or a selection indicator
on light surfaces. Haldi buttons are compliant because their ink label identifies them.

---

## 4. Typography

All fonts are **SIL OFL 1.1** (Google Fonts). Files + licences: `fonts/` (static instances in `fonts/static/`
for bundling, variable originals in `fonts/variable/`, licences in `fonts/licenses/`).

| Role | Font | Why |
|---|---|---|
| Display: headlines, prices, badges, the wordmark | **Bricolage Grotesque** ExtraBold 75% width (static "BricolageCondensed") and Bold (static "BricolageGrotesque") | Condensed grotesque with ink-trap character: the sign-painter confidence without kitsch; long brand names fit; numerals are strong. |
| UI and reading text | **Instrument Sans** 400/500/600/700 | Crisp, neutral, open shapes at 12–16 px, has **tabular figures** (`tnum`) so prices align. |
| Urdu | **Noto Nastaliq Urdu** 400/700 | Real Nastaliq, the script Urdu readers expect; correct Urdu shaping and dots. |
| Urdu controls | Noto Naskh Arabic 400/700 | Controls and inputs: buttons, chips, tabs, labels, text fields, list-tile titles and small meta text. |

**Nastaliq vs Naskh.** Nastaliq is how Urdu is read in Pakistan (Jang, signage, poetry). It looks native and
respectful, but it is tall (natural line ≈ 2.5 em), slower to shape and has no tabular figures. Naskh is compact
and fast but reads as Arabic or "computer Urdu". Decision (revised in sub-phase 1.6 after QA): **Nastaliq for
headings and reading text** (display, headline, title large/medium, body medium, the default for plain text);
**Naskh for controls and inputs** (label styles, body large, title small, body small), where Nastaliq's height
breaks fixed component bounds even at 1.9–2.1 line height. The wordmark is always Nastaliq.

### Type scale
| Token | Font | Size / line-height | Weight | Notes |
|---|---|---|---|---|
| displayLarge | Bricolage Condensed | 44 / 1.04 | 800 | Hero numbers ("40% OFF") |
| displayMedium | Bricolage Condensed | 36 / 1.06 | 800 | |
| headline | Bricolage Condensed | 28 / 1.10 | 800 | Section and deal titles |
| price | Bricolage Condensed | 28 / 1.00 | 800 | `tnum` |
| badge | Bricolage Condensed | 15 / 1.00 | 800 | "-40%", +0.3 tracking |
| titleLarge | Bricolage Grotesque | 22 / 1.25 | 700 | Card and app-bar titles |
| titleMedium | Instrument Sans | 17 / 1.35 | 600 | List titles |
| bodyLarge | Instrument Sans | 16 / 1.50 | 400 | |
| bodyMedium | Instrument Sans | 14 / 1.45 | 400 | Default |
| bodySmall | Instrument Sans | 12 / 1.40 | 400 | Meta: distance, expiry |
| labelLarge | Instrument Sans | 15 / 1.20 | 600 | Buttons |
| labelSmall | Instrument Sans | 12 / 1.20 | 600 | Chips, +0.3 tracking |
| numeric | Instrument Sans | 14 / 1.30 | 500 | `tnum` |
| urduDisplay | Noto Nastaliq Urdu | 34 / 2.0 | 700 | |
| urduHeadline | Noto Nastaliq Urdu | 26 / 2.0 | 700 | |
| urduTitle | Noto Nastaliq Urdu | 20 / 2.0 | 700 | |
| urduBody | Noto Nastaliq Urdu | 18 / 2.1 | 400 | Latin body 16 → Urdu 18 |
| urduBodySmall | Noto Nastaliq Urdu | 15 / 2.1 | 400 | |
| urduLabel | Noto Nastaliq Urdu | 16 / 1.9 | 700 | Buttons, chips |

Rules: Urdu styles always use their own tokens (never a Latin style with an Urdu string); never letter-space Urdu;
Urdu styles fall back to Instrument Sans for embedded Latin (brand names, prices); use Western digits (0–9) in UI
for both languages; test every screen at 200% text size in Urdu (Nastaliq lines grow fast); give inputs and chips
minimum heights, not fixed heights.

---

## 5. Shape, space, elevation, motion

- **Radii:** 4 (badges: stamps, not pills), 8 (buttons, inputs), 12 (cards), 16, 24 (sheets), full (avatars).
- **Spacing:** 4-pt scale 2/4/8/12/16/20/24/32/40/48/64; 16 dp screen gutter; 48 dp touch targets.
- **Elevation:** shadows tinted with Surma, low opacity (levels 1–3). Dark theme uses surface steps, not shadows.
  `stamp` = hard 3/3 offset ink shadow, no blur: marketing tiles and promo badges only.
- **Motion:** fast 140 ms, base 220 ms, slow 320 ms. `stamp` (180 ms, slight overshoot): the nuqta landing, used
  once per screen at most (new-deal badge, alert confirmation). Splash animation, if built: the nuqta stamps, then
  the alif is drawn top to bottom (≤ 700 ms).

## 6. Iconography

- UI icons: **Material Symbols Rounded** (Apache 2.0), weight 500, grade 0, optical size 24; outlined by default,
  **filled for the selected state**. One set only; don't mix with other icon packs.
- Custom brand glyphs: the Qalam Bang (alerts, notifications) and the nuqta (new/unread dot, bullets, step markers).
  Unread dot = Mirch nuqta, 8 dp.
- Category icons (fashion, food, cards, telecom, grocery, salon): Material Symbols, ink on a Haldi 100 circle.
  No 3D, no emoji-style, no gradients.
- Deal badge: Mirch fill, white `badge` text "-40%", radius 4. Featured/sponsored badge: Haldi fill, ink text,
  always the word "Featured" (or "نمایاں"); paid placement is never disguised.

## 7. Illustration and photography

- **Photos (deal cards):** real product or place photos supplied by the business, 4:3, centred subject, natural
  colour. Reject watermarked, text-heavy flyers as the hero image: show the flyer as a secondary image instead.
  Never add filters or fake "SALE" stickers to a business's photo; the badge does that job.
- **Brand photography (marketing):** real Karachi and Lahore streets, malls and dhabas, people of the audience
  age, daylight or warm night-market light. No stock "woman jumping with shopping bags", no fake luxury.
- **Illustration (empty states, onboarding):** flat two-tone cut-paper style in Surma line + one Haldi shape;
  everyday bazaar objects (a rolled shutter, a lawn suit on a hanger, a chai cup, a card machine). One object per
  scene, generous white space. No 3D characters, no blobs, no sparkles.
- Local culture: use with restraint. A single truck-art border on an Eid campaign is fine; turning the UI into a
  truck is not.

## 8. Voice (summary)

Bazaar-smart, quick, honest, warm, proudly local. Lead with brand + offer + deadline. **One exclamation mark per
message, and it's ours.** One emoji at most (🔔 for alerts). Exact numbers and real end dates; "up to" only with
what it applies to. Urdu locale uses Urdu script; Roman Urdu is for push/marketing. Full table with English,
Roman Urdu and Urdu examples: `BRAND_STRATEGY.md` §4.

## 9. Open decisions for the owner

1. **Name.** Designed for "Sale Lagi Hai!". A rename means regenerating the wordmarks (scripted, see strategy §5).
2. **Icon colourway.** Primary is ink bang on Haldi (loudest on a home screen). Black-on-yellow "!" is also the
   language of hazard signs; if user testing shows people read it as "warning", switch to the Raat alternate
   (`app-icon/png/play-store-512-alt-raat.png`, Haldi on ink).
3. **Urdu proofreading.** All Urdu copy and the Urdu wordmark need a native-speaker check (spelling, register).
4. **Trademark.** Run a search on the name and the "!" mark in Pakistan (IPO-Pakistan) before filing.
5. **Competitor colours.** I could not verify Golootlo, Peekaboo Guru, Bogo or Vouch365 brand colours from this
   environment (their sites were not reachable). Daraz orange and Foodpanda pink were avoided. Please confirm none
   of them is a yellow/ink brand.
6. **Naskh fallback.** Keep or drop the optional Noto Naskh Arabic files (≈ 400 KB) from the app bundle.

## 10. Regenerating

```
pip install fonttools uharfbuzz           # once
python3 design/_src/build_tokens.py       # tokens JSON, Dart, contrast report (fails on any contrast miss)
python3 design/_src/build_final.py        # all logo + app-icon SVG/PNG/XML
python3 design/_src/preview_sheet.py      # app-icon/preview-sheet.png
python3 design/_src/brand_board.py        # brand-board.html -> brand-board.png
python3 design/_src/concepts.py && python3 design/_src/sheet.py   # concept sources + critique sheet
```
