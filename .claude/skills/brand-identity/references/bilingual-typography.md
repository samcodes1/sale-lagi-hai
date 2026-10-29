# Bilingual typography: Latin + Urdu

## Licences
Only OFL (SIL Open Font License 1.1) or Apache 2.0 fonts. Google Fonts' repository lists the licence per family
(`ofl/<family>/METADATA.pb`, `OFL.txt`). Check `OFL.txt` for a "Reserved Font Name": if present, a modified
version (including a static instance you generate) must be renamed. Bundle the licence file next to the fonts.
Logos built from OFL glyph outlines are fine: the OFL governs the font software, not artwork made with it.

## Choosing faces by job
| Job | Needs | Example (OFL) |
|---|---|---|
| Latin display (headlines, prices, badges) | personality, strong numerals, condensed width for long brand names | Bricolage Grotesque (opsz/wdth/wght) |
| Latin UI text | legibility at 12–16 px, open apertures, **tabular figures** (`tnum`) | Instrument Sans |
| Urdu reading text | Nastaliq, correct Urdu shaping and dots, two weights | Noto Nastaliq Urdu |
| Urdu compact (optional) | short numeric labels where height is constrained | Noto Naskh Arabic |

Check features with fontTools (`GSUB` feature list) before committing: e.g. Hanken Grotesk lacks `tnum`.

## Nastaliq vs Naskh
- **Nastaliq** is how Urdu is written and printed (newspapers, signage, poetry). It cascades diagonally right-to-left
  and occupies a lot of vertical space. Noto Nastaliq Urdu metrics: ascent 1904, descent 596 per 1000 upm, so the
  natural line is ~2.5 em. Shaping is heavier than Naskh and there are no tabular figures.
- **Naskh** is compact and fast, matches Arabic UI conventions, and many systems default to it for Urdu, but Urdu
  readers often perceive it as Arabic or as "computer Urdu". Fontconfig maintainers and Urdu communities disagree about
  defaults; for an Urdu-first audience, Nastaliq signals respect and native quality.
- Decision rule: Nastaliq for everything people read; Naskh only where a fixed-height component cannot grow (and
  prefer redesigning the component first).

## Sizing and spacing
- Equal point size looks smaller in Nastaliq: set Urdu +2–4 px over the Latin twin (body 16 → 18).
- Line height 1.9–2.2 for Nastaliq (community reports: 1.2–1.5 clips nuqtas and overlaps lines). Test on device.
- Input fields, chips and buttons need extra height in Urdu; never fix their height in px.
- Do not try to match x-heights (Arabic script has none). Match stroke weight and overall color.
- Letter-spacing on Arabic script breaks joining: never track Urdu.

## RTL
- Mirror layout (padding, icons with direction, progress) not glyphs. Punctuation like "!" and digits are not mirrored.
- Latin brand names, prices and codes inside Urdu sentences stay Latin: give Urdu styles a Latin fallback and vice versa.
- Pakistani apps mostly use Western digits (0–9) in Urdu UI; Urdu digits (۰–۹) are fine in editorial text. Pick one
  per surface and stay consistent.

## Flutter notes
- Bundle static instances (one file per weight) and map them by `weight:` in `pubspec.yaml`; this avoids variable-font
  axis issues. Generate them with `fontTools.varLib.instancer`.
- Urdu `TextStyle`: `height: 2.0–2.1`, `leadingDistribution: TextLeadingDistribution.even`, `fontFamilyFallback`
  with the Latin UI family. Consider a `StrutStyle` in lists for even row heights.
- Use `Directionality`/locale-driven `TextDirection.rtl`; test at 200% text scale.

## Outlining Urdu lettering for a logo
1. Shape the string with HarfBuzz (`uharfbuzz`): it applies init/medi/fina forms, ligatures, mark positioning
   (`mark`, `mkmk`, `curs`). Never place glyphs by cmap lookup alone.
2. Draw each shaped glyph with fontTools `SVGPathPen` + `TransformPen` (flip y, apply x/y offsets and advances).
3. Render the same string in a browser with the same font and compare: every nuqta, the gaf's second stroke,
   heh forms, yeh barree.
4. Have a native reader check spelling and that the phrase reads naturally.
