"""Convert shaped text to SVG path outlines (HarfBuzz shaping + fontTools pens).
Used to build the wordmark and Urdu lockup as outlines, so no font is needed to display them."""
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

_cache = {}
def _load(path):
    if path not in _cache:
        blob = hb.Blob.from_file_path(path)
        _cache[path] = (TTFont(path), hb.Face(blob))
    return _cache[path]

def shape(path, text, variations=None, features=None, direction=None, script=None, language=None):
    tt, face = _load(path)
    font = hb.Font(face)
    if variations:
        font.set_variations(variations)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    if direction: buf.direction = direction
    if script: buf.script = script
    if language: buf.language = language
    hb.shape(font, buf, features or {})
    return tt, buf.glyph_infos, buf.glyph_positions

def text_path(path, text, size, x=0, y=0, variations=None, features=None, tracking=0, **kw):
    """Returns (d, advance_width, bounds) for text set at `size` px with baseline at y.
    tracking is in font units added after each glyph."""
    tt, infos, poss = shape(path, text, variations, features, **kw)
    upem = tt['head'].unitsPerEm
    s = size / upem
    gs = tt.getGlyphSet(location=variations or None, normalized=False) if variations else tt.getGlyphSet()
    order = tt.getGlyphOrder()
    pen = SVGPathPen(gs)
    bp = BoundsPen(gs)
    cx = 0
    for info, pos in zip(infos, poss):
        name = order[info.codepoint]
        gx = x + (cx + pos.x_offset) * s
        gy = y - pos.y_offset * s
        t = (s, 0, 0, -s, gx, gy)
        gs[name].draw(TransformPen(pen, t))
        gs[name].draw(TransformPen(bp, t))
        cx += pos.x_advance + tracking
    return pen.getCommands(), cx * s, bp.bounds

def glyph_names(path, text, **kw):
    tt, infos, poss = shape(path, text, **kw)
    order = tt.getGlyphOrder()
    return [(order[i.codepoint], p.x_advance) for i, p in zip(infos, poss)]

def text_glyphs(path, text, size, x=0, y=0, variations=None, features=None, tracking=0, kerns=None, **kw):
    """Like text_path but returns a list of per-glyph dicts {name, d, x, adv, bounds}.
    kerns: optional {index: extra_units} added before glyph index (manual spacing)."""
    tt, infos, poss = shape(path, text, variations, features, **kw)
    upem = tt['head'].unitsPerEm
    s = size / upem
    gs = tt.getGlyphSet(location=variations, normalized=False) if variations else tt.getGlyphSet()
    order = tt.getGlyphOrder()
    out = []
    cx = 0
    for i, (info, pos) in enumerate(zip(infos, poss)):
        if kerns and i in kerns:
            cx += kerns[i]
        name = order[info.codepoint]
        gx = x + (cx + pos.x_offset) * s
        gy = y - pos.y_offset * s
        t = (s, 0, 0, -s, gx, gy)
        pen = SVGPathPen(gs); bp = BoundsPen(gs)
        gs[name].draw(TransformPen(pen, t)); gs[name].draw(TransformPen(bp, t))
        out.append(dict(name=name, d=pen.getCommands(), x=gx, adv=pos.x_advance * s, bounds=bp.bounds))
        cx += pos.x_advance + tracking
    return out, cx * s
