"""Builds the app's Urdu fonts from the originals in design/fonts/static.

The Noto Urdu fonts also carry their own Latin letters and digits. Flutter
falls back to the next font only for glyphs the first font lacks, so an Urdu
style would draw brand names and prices ("Khaadi", "Rs 2,999") in Noto's
Latin instead of Instrument Sans, which the brand guidelines require
(BRAND_GUIDELINES.md, Typography). This removes those glyphs so they fall
back to the Latin UI font. Everything Urdu, including Arabic-script
punctuation and the shaping rules, is kept.

The fonts are under the SIL Open Font License 1.1 with no Reserved Font
Name, which allows modified copies under the same name.

Run from the repo root:  python3 tool/subset_urdu_fonts.py
"""

from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

SOURCE = Path("design/fonts/static")
TARGET = Path("assets/fonts")
FONTS = [
    "NotoNastaliqUrdu-Regular",
    "NotoNastaliqUrdu-Bold",
    "NotoNaskhArabic-Regular",
    "NotoNaskhArabic-Bold",
]

# Latin letters, digits and the number punctuation used in prices, so a
# number such as "2,999" or "40%" is drawn in one font.
REMOVED = (
    set(range(ord("A"), ord("Z") + 1))
    | set(range(ord("a"), ord("z") + 1))
    | set(range(ord("0"), ord("9") + 1))
    | {ord(","), ord("."), ord("%")}
    | set(range(0x00C0, 0x0250))  # Latin-1 letters and Latin Extended A/B
)


def build(name: str) -> None:
    source = SOURCE / f"{name}.ttf"
    kept = sorted(set(TTFont(source).getBestCmap()) - REMOVED)

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    options.notdef_outline = True
    options.glyph_names = True
    options.hinting = True
    options.legacy_kern = True
    options.drop_tables = []

    font = TTFont(source)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=kept)
    subsetter.subset(font)
    font.save(TARGET / f"{name}.ttf")
    print(f"{name}: kept {len(kept)} code points")


if __name__ == "__main__":
    for font_name in FONTS:
        build(font_name)
