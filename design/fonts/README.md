# Brand fonts

All families are licensed under the **SIL Open Font License 1.1** (no Reserved Font Names); licences are in
`licenses/`. Downloaded from the Google Fonts repository (`github.com/google/fonts`, `ofl/<family>/`) on 2026-10-29.

| Folder | Contents |
|---|---|
| `variable/` | Original variable fonts as published (Bricolage Grotesque opsz/wdth/wght, Instrument Sans wdth/wght, Noto Nastaliq Urdu wght, Noto Naskh Arabic wght). Used by the logo generators. |
| `static/` | Static instances made with `fontTools.varLib.instancer` for bundling in Flutter (one file per weight). |

| Static file | Instance | pubspec family / weight |
|---|---|---|
| BricolageGrotesqueCondensed-ExtraBold.ttf | wght 800, wdth 75, opsz 96 | BricolageCondensed / 800 |
| BricolageGrotesque-Bold.ttf | wght 700, wdth 100, opsz 24 | BricolageGrotesque / 700 |
| InstrumentSans-{Regular,Medium,SemiBold,Bold}.ttf | wght 400/500/600/700, wdth 100 | InstrumentSans / 400–700 |
| NotoNastaliqUrdu-{Regular,Bold}.ttf | wght 400/700 | NotoNastaliqUrdu / 400, 700 |
| NotoNaskhArabic-{Regular,Bold}.ttf | wght 400/700 (optional) | NotoNaskhArabic / 400, 700 |

Copy `static/*.ttf` to the app's `assets/fonts/` and ship the matching `licenses/OFL-*.txt` with the app
(e.g. register them with `LicenseRegistry` so they appear on the licences page). The pubspec snippet is at the end
of `../flutter/brand_tokens.dart`.
