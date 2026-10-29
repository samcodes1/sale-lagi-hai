"""Source of truth for the final Sale Lagi Hai! identity geometry.
Symbol: the Qalam Bang. Wordmark: Bricolage Grotesque ExtraBold 75% width, converted to outlines,
with every i-dot replaced by a nuqta and the closing bang drawn by hand.
Run build_final.py to regenerate every SVG/PNG from this file."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from textpath import text_glyphs

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, '..', 'fonts', 'variable')
BRI = os.path.join(FONTS, 'BricolageGrotesque[opsz,wdth,wght].ttf')
NAS = os.path.join(FONTS, 'NotoNastaliqUrdu[wght].ttf')

# Brand colours (see tokens/brand_tokens.json for the full system)
HALDI = '#FFC414'   # turmeric yellow, primary surface
SURMA = '#1A1433'   # kohl ink, primary text/mark
KAGHAZ = '#FFF8E7'  # paper
MIRCH = '#E8352B'   # chilli, deal/hot accent only

def f(v):
    s = f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

# ---- The Qalam Bang, drawn on a 100-unit grid ---------------------------------
# Bar = a Nastaliq alif: top cut on the nib angle (~33 deg), full nib width, the
# pen easing off into a point. Dot = nuqta, a square on its corner, slightly
# softened corners (a reed nib is never razor sharp). Gap = 0.35 nuqta.
BAR = [(45, 22), (68, 7), (66, 32), (55, 53), (49, 62.5), (46, 62.8), (43.5, 50), (43.5, 35)]
DOT = (43.2, 80.5, 11.5, 1.5)   # cx, cy, half-diagonal, corner radius
BANG_BOUNDS = (31.7, 7.0, 68.0, 92.0)   # x0, y0, x1, y1 on the 100 grid

def _diamond(cx, cy, r, rr):
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    d = ''
    for i in range(4):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % 4]
        def tw(a, b, t):
            L = math.dist(a, b); return (a[0] + (b[0] - a[0]) * t / L, a[1] + (b[1] - a[1]) * t / L)
        s, e = tw(p1, p0, rr), tw(p1, p2, rr)
        d += ('M' if i == 0 else 'L') + f'{f(s[0])} {f(s[1])}Q{f(p1[0])} {f(p1[1])} {f(e[0])} {f(e[1])}'
    return d + 'Z'

def nuqta(cx, cy, r, rr=None):
    """Brand nuqta (also used as i-dots, bullets, list markers)."""
    return _diamond(cx, cy, r, rr if rr is not None else r * 0.13)

def bang(sx=1.0, tx=0.0, ty=0.0, sy=None):
    """Qalam Bang path, transformed: x' = x*sx + tx, y' = y*sy + ty."""
    sy = sy if sy is not None else sx
    T = lambda p: (p[0] * sx + tx, p[1] * sy + ty)
    b = [T(p) for p in BAR]; fm = lambda p: f'{f(p[0])} {f(p[1])}'
    bar = f'M{fm(b[0])}L{fm(b[1])}C{fm(b[2])} {fm(b[3])} {fm(b[4])}L{fm(b[5])}C{fm(b[6])} {fm(b[7])} {fm(b[0])}Z'
    cx, cy, r, rr = DOT
    return bar + _diamond(cx * sx + tx, cy * sy + ty, r * sx, rr * sx)

def bang_fit(cx, top, height):
    """Bang scaled to `height`, its bbox horizontally centred on cx (optically nudged +3%)."""
    x0, y0, x1, y1 = BANG_BOUNDS
    s = height / (y1 - y0)
    tx = cx - (x0 + x1) / 2 * s + 0.03 * height * 0  # keep geometric centre; nudge handled per use
    return bang(s, tx, top - y0 * s), s

def symbol_svg(fg=SURMA, bg=None, size=None, box=100, mark_h=None, rx=0, cx_nudge=1.2):
    """Square symbol. mark_h = bang height inside the 100 box (default 85 = full)."""
    mark_h = mark_h or 85
    top = (100 - mark_h) / 2
    d, _ = bang_fit(50 + cx_nudge * mark_h / 85, top, mark_h)
    w = f' width="{size}" height="{size}"' if size else ''
    bgr = f'<rect width="100" height="100" rx="{rx}" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"{w}>{bgr}<path d="{d}" fill="{fg}"/></svg>'

# ---- Wordmark --------------------------------------------------------------------
WM_VAR = {'wght': 800, 'wdth': 75, 'opsz': 96}

def wordmark_paths(text='Sale Lagi Hai', size=100, var=None, tracking=-4, bang_gap=6, kerns=None,
                   bang_h=76, bang_wx=1.12, dot_r=9.2, dot_gap=4.6):
    """Returns (svg inner markup without fill, width, cap_height). Baseline at y=0.
    Every 'i' is set as dotless i with a nuqta above it; the closing bang is the Qalam Bang,
    drawn taller than the caps (it is the shout) and widened x1.12 to match the ExtraBold colour."""
    var = var or WM_VAR
    txt = text.replace('i', '\u0131')
    gl, w = text_glyphs(BRI, txt, size, 0, 0, var, tracking=tracking, kerns=kerns)
    parts = [g['d'] for g in gl if g['d']]
    s = size / 100
    for g in gl:
        if g['name'] == 'dotlessi':
            x0, y0, x1, y1 = g['bounds']
            r = dot_r * s
            cx = (x0 + x1) / 2 + 0.8 * s      # a hair right: follows the bang's lean
            parts.append(nuqta(cx, y0 - dot_gap * s - r, r))
    cap = 66 * s
    H = bang_h * s
    last = gl[-1]['bounds']
    bx0, by0, bx1, by1 = BANG_BOUNDS
    sy = H / (by1 - by0); sx = sy * bang_wx
    left = last[2] + bang_gap * s
    tx = left - bx0 * sx
    ty = (1.6 * s - H) - by0 * sy        # diamond point overshoots the baseline by 1.6%
    parts.append(bang(sx, tx, ty, sy))
    width = left + (bx1 - bx0) * sx
    return ''.join(f'<path d="{p}"/>' for p in parts), width, max(cap, H)

def wordmark_svg(fg=SURMA, bg=None, pad=None, size=100, **kw):
    inner, w, cap = wordmark_paths(size=size, **kw)
    pad = pad if pad is not None else 0
    top = -cap - 2 * size / 100 - pad
    h = cap + 2 * size / 100 + 17 * size / 100 + 2 * pad
    bgr = f'<rect x="{-pad}" y="{f(top)}" width="{f(w + 2 * pad)}" height="{f(h)}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{f(-pad)} {f(top)} {f(w + 2 * pad)} {f(h)}">'
            f'{bgr}<g fill="{fg}">{inner}</g></svg>'), (w + 2 * pad, h)

# ---- Urdu lockup -----------------------------------------------------------------
def urdu_paths(size=100, wght=700, text='سیل لگی ہے'):
    """'سیل لگی ہے' shaped by HarfBuzz with Noto Nastaliq Urdu, then the Qalam Bang
    placed at the left (end of the RTL sentence). Baseline y=0. Returns (markup, x0, x1, top, bottom)."""
    gl, w = text_glyphs(NAS, text, size, 0, 0, {'wght': wght})
    parts = [g['d'] for g in gl if g['d']]
    bs = [g['bounds'] for g in gl if g['bounds']]
    x0 = min(b[0] for b in bs); x1 = max(b[2] for b in bs)
    y0 = min(b[1] for b in bs); y1 = max(b[3] for b in bs)
    # bang: same height as the tallest letter stroke (lam/gaf), sits on the baseline zone
    H = (0 - y0) * 0.70
    bx0, by0, bx1, by1 = BANG_BOUNDS
    sc = H / (by1 - by0)
    right = x0 - 0.045 * size
    tx = right - bx1 * sc
    ty = -H + 0.085 * size - by0 * sc
    parts.append(bang(sc, tx, ty))
    return ''.join(f'<path d="{p}"/>' for p in parts), right - (bx1 - bx0) * sc, x1, min(y0, -H + 0.085 * size), max(y1, 0.085 * size)

def urdu_svg(fg=SURMA, bg=None, pad=8, size=100):
    inner, x0, x1, y0, y1 = urdu_paths(size)
    vb = (x0 - pad, y0 - pad, x1 - x0 + 2 * pad, y1 - y0 + 2 * pad)
    bgr = f'<rect x="{f(vb[0])}" y="{f(vb[1])}" width="{f(vb[2])}" height="{f(vb[3])}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{" ".join(f(v) for v in vb)}">{bgr}<g fill="{fg}">{inner}</g></svg>'), vb
