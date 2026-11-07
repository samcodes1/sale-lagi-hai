"""Second logo round. Usage: python concepts_v2.py <out_dir>

Needs fonttools and uharfbuzz. Lettering is real font outlines, shaped with
HarfBuzz so the Urdu is never hand-faked. Every mark sits on a 512 tile and
stays inside the launcher safe circle (radius 234).
"""
import math
import pathlib
import sys

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONTS = pathlib.Path(__file__).resolve().parent.parent / "fonts" / "static"
LATIN = FONTS / "BricolageGrotesqueCondensed-ExtraBold.ttf"
URDU = FONTS / "NotoNastaliqUrdu-Bold.ttf"

HALDI = "#FFC414"
SURMA = "#1A1433"
MIRCH = "#DC2E24"
NEEL = "#3B3FD9"
KAGHAZ = "#FFF8E7"


def outline(font_path, text, box, stretch=True):
    """Shapes [text] and fits its outlines to box = (x, y, w, h)."""
    tt = TTFont(font_path)
    glyphs = tt.getGlyphSet()
    face = hb.Face(hb.Blob.from_file_path(str(font_path)))
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf)

    placed = []
    cursor = 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = tt.getGlyphName(info.codepoint)
        placed.append((name, cursor + pos.x_offset, pos.y_offset))
        cursor += pos.x_advance

    bounds = BoundsPen(glyphs)
    for name, gx, gy in placed:
        glyphs[name].draw(TransformPen(bounds, (1, 0, 0, 1, gx, gy)))
    x0, y0, x1, y1 = bounds.bounds

    bx, by, bw, bh = box
    sx, sy = bw / (x1 - x0), bh / (y1 - y0)
    if not stretch:
        sx = sy = min(sx, sy)
    ox = bx + (bw - (x1 - x0) * sx) / 2 - x0 * sx
    oy = by + (bh - (y1 - y0) * sy) / 2 + y1 * sy

    pen = SVGPathPen(glyphs, ntos=lambda v: f"{v:.1f}".rstrip("0").rstrip("."))
    for name, gx, gy in placed:
        matrix = (sx, 0, 0, -sy, ox + gx * sx, oy - gy * sy)
        glyphs[name].draw(TransformPen(pen, matrix))
    return pen.getCommands()


def naam_block(c):
    """The full name is a perfect 4x3 block: SALE / LAGI / HAI!"""
    x, w, h, gap = 106, 300, 104, 13
    y = 256 - (3 * h + 2 * gap) / 2
    sale = outline(LATIN, "SALE", (x, y, w, h))
    lagi = outline(LATIN, "LAGI", (x, y + h + gap, w, h))
    hai = outline(LATIN, "HAI", (x, y + 2 * (h + gap), w * 0.74, h))
    bang = outline(LATIN, "!", (x + w * 0.82, y + 2 * (h + gap), w * 0.18, h))
    return (
        f'<rect width="512" height="512" fill="{c["bg"]}"/>'
        f'<path fill="{c["fg"]}" d="{sale}{lagi}{hai}"/>'
        f'<path fill="{c["accent"]}" d="{bang}"/>'
    )


def s_percent(c):
    """The S of Sale is the slash of a % sign."""
    half = (
        "M404 118C330 74 214 92 226 178C233 228 279 284 286 334"
        "C298 420 182 438 108 394"
    )
    return (
        f'<rect width="512" height="512" fill="{c["bg"]}"/>'
        f'<path d="{half}" fill="none" stroke="{c["fg"]}" stroke-width="78"/>'
        f'<circle cx="116" cy="182" r="52" fill="{c["accent"]}"/>'
        f'<circle cx="396" cy="330" r="52" fill="{c["accent"]}"/>'
    )


def urdu_shout(c):
    """The word sale, in Nastaliq, shouted."""
    word = outline(URDU, "سیل!", (64, 84, 384, 344), stretch=False)
    return (
        f'<rect width="512" height="512" fill="{c["bg"]}"/>'
        f'<path fill="{c["fg"]}" d="{word}"/>'
    )


def sale_sticker(c):
    """The burst sticker on every shop window, cut by a calligrapher's nib."""
    points = []
    for i in range(24):
        angle = math.radians(i * 15 - 8)
        radius = 234 if i % 2 == 0 else 196
        points.append(
            f"{256 + radius * math.cos(angle):.1f},"
            f"{256 + radius * math.sin(angle):.1f}"
        )
    word = outline(LATIN, "SALE", (116, 186, 280, 140))
    return (
        f'<rect width="512" height="512" fill="{c["bg"]}"/>'
        f'<polygon fill="{c["accent"]}" points="{" ".join(points)}"/>'
        f'<g transform="rotate(-8 256 256)"><path fill="{c["fg"]}" d="{word}"/></g>'
    )


CONCEPTS = [
    ("A", "Naam Block", naam_block,
     {"bg": MIRCH, "fg": KAGHAZ, "accent": HALDI}),
    ("B", "S Percent", s_percent,
     {"bg": SURMA, "fg": HALDI, "accent": KAGHAZ}),
    ("C", "Urdu Shout", urdu_shout,
     {"bg": NEEL, "fg": KAGHAZ, "accent": KAGHAZ}),
    ("D", "Sale Sticker", sale_sticker,
     {"bg": HALDI, "fg": KAGHAZ, "accent": MIRCH}),
]
MONO = {"bg": "#FFFFFF", "fg": "#000000", "accent": "#000000"}
MONO_KNOCKOUT = {"bg": "#FFFFFF", "fg": "#FFFFFF", "accent": "#000000"}


def svg(inner, size):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}"'
        f' viewBox="0 0 512 512">{inner}</svg>'
    )


def tile(inner, size, radius="23%"):
    return (
        f'<span style="display:inline-block;width:{size}px;height:{size}px;'
        f'border-radius:{radius};overflow:hidden;line-height:0;flex:none">'
        f"{svg(inner, size)}</span>"
    )


def sheet(out):
    rows = []
    for key, name, draw, colors in CONCEPTS:
        art = draw(colors)
        (out / f"{key}_{name.lower().replace(' ', '_')}.svg").write_text(
            svg(art, 512)
        )
        small = "".join(tile(art, s) for s in (96, 72, 48, 36, 24, 16))
        rows.append(
            f"<section><h2>{key}. {name}</h2><div class=row>"
            f"{tile(art, 220)}{tile(art, 220, '50%')}"
            f"{tile(draw(MONO_KNOCKOUT if key == 'D' else MONO), 220)}"
            f"<div class=small>{small}</div>"
            "</div></section>"
        )
    (out / "sheet.html").write_text(
        "<!doctype html><meta charset=utf-8><style>"
        "body{margin:0;padding:28px;background:#E9E5DE;font:600 22px sans-serif}"
        "h2{margin:18px 0 10px;color:#1A1433}"
        ".row{display:flex;gap:22px;align-items:center}"
        ".small{display:flex;gap:14px;align-items:center;margin-left:10px}"
        "</style>" + "".join(rows)
    )


if __name__ == "__main__":
    target = pathlib.Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)
    sheet(target)
