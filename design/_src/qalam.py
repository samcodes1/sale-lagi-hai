"""Qalam Bang: an exclamation mark drawn with the logic of a reed pen (qalam).
Bar = Nastaliq alif: cut flat at the nib angle, full nib width, tapering as the pen lifts.
Dot = nuqta: the rhombus the same nib stamps. Everything derives from one nib (width n, angle)."""
import math

def _rot(p, a):
    c, s = math.cos(a), math.sin(a)
    x, y = p
    return (x * c - y * s, x * s + y * c)

def f(v):
    s = f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

def qalam_bang_geom(n=24.0, nib_deg=50.0, lean_deg=12.0, length_k=2.35, gap_k=0.34,
                    tip_k=0.22, stroke_k=0.86, swell=0.06, flank_curve=True):
    """Return dict of shapes in un-normalised units (y down). n = nib width.
    length_k: alif length in nib widths (a Lahori alif ~3 nuqtas; nuqta ~0.8n tall)."""
    na = math.radians(nib_deg)
    lean = math.radians(lean_deg)
    W = n                      # bar width = nib width
    L = length_k * n * 1.0 + W * math.tan(na) / 2  # axis length from top-centre to tip
    t = tip_k * n              # tip width (pen lifting)
    h = W / 2 * math.tan(na)   # half rise of the top cut
    # un-leaned bar, top-centre at (0,0). y down. Cut rises to the right.
    TL = (-W / 2, h); TR = (W / 2, -h)
    BL = (-t / 2, L + t / 2 * math.tan(na)); BR = (t / 2, L - t / 2 * math.tan(na))
    # cubic flanks: hold the width, then taper over the last ~40%
    rc1 = (W / 2 + swell * n, L * 0.42); rc2 = (W * 0.42, L * 0.86)
    lc2 = (-W / 2 - swell * n * 0.2, L * 0.50); lc1 = (-W * 0.40, L * 0.90)
    # nuqta: parallelogram, side a along nib (length n*0.98), side b along stroke (perp to nib)
    a = (math.cos(-na) * n * 0.98, math.sin(-na) * n * 0.98)          # nib edge direction (rising right)
    b = (math.cos(math.pi / 2 - na) * n * stroke_k, math.sin(math.pi / 2 - na) * n * stroke_k)  # pen pulled down-right
    # nuqta centre below the tip
    dn_h = abs(a[1]) + abs(b[1])
    cy = L + gap_k * n + dn_h / 2
    c = (-0.02 * n, cy)
    P0 = (c[0] - (a[0] + b[0]) / 2, c[1] - (a[1] + b[1]) / 2)
    N = [P0, (P0[0] + a[0], P0[1] + a[1]), (P0[0] + a[0] + b[0], P0[1] + a[1] + b[1]), (P0[0] + b[0], P0[1] + b[1])]
    R = lambda p: _rot(p, lean)
    bar = [R(TL), R(TR), R(rc1), R(rc2), R(BR), R(BL), R(lc1), R(lc2)]
    N = [R(p) for p in N]
    return bar, N

def qalam_bang_path(box=(0, 0, 100, 100), height=None, cx=None, **kw):
    """Fit the mark to a box (x, y, w, h): scaled to `height` (default box h), centred
    on optical centre (bbox centre nudged toward the heavier bar)."""
    bar, N = qalam_bang_geom(**kw)
    pts = bar + N
    # bounds of polygon approx (control points are inside hull, good enough + exact below)
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    bx, by, bw, bh = box
    H = height or bh
    s = H / (y1 - y0)
    ox = (cx if cx is not None else bx + bw / 2) - (x0 + x1) / 2 * s
    oy = by + (bh - H) / 2 - y0 * s
    T = lambda p: (p[0] * s + ox, p[1] * s + oy)
    b = [T(p) for p in bar]; n = [T(p) for p in N]
    d = (f'M{f(b[0][0])} {f(b[0][1])}L{f(b[1][0])} {f(b[1][1])}'
         f'C{f(b[2][0])} {f(b[2][1])} {f(b[3][0])} {f(b[3][1])} {f(b[4][0])} {f(b[4][1])}'
         f'L{f(b[5][0])} {f(b[5][1])}'
         f'C{f(b[6][0])} {f(b[6][1])} {f(b[7][0])} {f(b[7][1])} {f(b[0][0])} {f(b[0][1])}Z'
         f'M{f(n[0][0])} {f(n[0][1])}L{f(n[1][0])} {f(n[1][1])}L{f(n[2][0])} {f(n[2][1])}L{f(n[3][0])} {f(n[3][1])}Z')
    return d, dict(scale=s, width=(x1 - x0) * s, x0=x0 * s + ox, x1=x1 * s + ox, y0=by + (bh - H) / 2, y1=by + (bh - H) / 2 + H)

def nuqta_path(cx, cy, size, nib_deg=50.0, lean_deg=12.0, stroke_k=0.86):
    """Stand-alone nuqta (used for i-dots and as a brand glyph). size = nib width."""
    na = math.radians(nib_deg); lean = math.radians(lean_deg); n = size
    a = (math.cos(-na) * n * 0.98, math.sin(-na) * n * 0.98)
    b = (math.cos(math.pi / 2 - na) * n * stroke_k, math.sin(math.pi / 2 - na) * n * stroke_k)
    P0 = (-(a[0] + b[0]) / 2, -(a[1] + b[1]) / 2)
    pts = [P0, (P0[0] + a[0], P0[1] + a[1]), (P0[0] + a[0] + b[0], P0[1] + a[1] + b[1]), (P0[0] + b[0], P0[1] + b[1])]
    pts = [_rot(p, lean) for p in pts]
    return 'M' + 'L'.join(f'{f(x + cx)} {f(y + cy)}' for x, y in pts) + 'Z'


def bang2_geom(W=1.0, L=2.3, nib_deg=40.0, lean_deg=12.0, taper=0.62, gap=0.36, pull=None, dot_scale=1.0, dot='slice'):
    """Straight-cut construction. Every edge is parallel either to the nib edge or to the stroke axis.
    Bar = the nib (width W) pulled down the axis for length L, pressure easing to `taper`.
    Dot = the same nib pulled a short distance (`pull`), i.e. a slice of the same stroke."""
    th = math.radians(nib_deg); lean = math.radians(lean_deg)
    tn = math.tan(th)
    # nib edge vector (perp width W, rising to the right)
    e = (W, -W * tn)
    TL = (-W / 2, W / 2 * tn); TR = (W / 2, -W / 2 * tn)
    w2 = W * taper
    BL = (-w2 / 2, L + w2 / 2 * tn); BR = (w2 / 2, L - w2 / 2 * tn)
    bar = [TL, TR, BR, BL]
    dw = W * dot_scale
    p = pull if pull is not None else dw / math.cos(th)  # rhombus when pull == edge length
    top = L + W * 0.5 * tn + gap  # clear space below the lowest bar corner
    # dot parallelogram: left vertex start at (-dw/2, y0 + dw/2*tn)
    y0 = top + dw / 2 * tn
    D = [(-dw / 2, y0), (dw / 2, y0 - dw * tn), (dw / 2, y0 - dw * tn + p), (-dw / 2, y0 + p)]
    if dot == 'diamond':
        cyy = top + (dw * tn + p) / 2
        hd = (dw * tn + p) / 2
        D = [(0, cyy - hd), (dw * 0.62, cyy - hd * 0.12), (0, cyy + hd), (-dw * 0.62, cyy + hd * 0.12)]
    R = lambda q: _rot(q, lean)
    return [R(q) for q in bar], [R(q) for q in D]

def bang2_path(box=(0, 0, 100, 100), height=None, cx=None, optical_dx=0.0, **kw):
    bar, D = bang2_geom(**kw)
    pts = bar + D
    xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    bx, by, bw, bh = box
    H = height or bh
    s = H / (y1 - y0)
    ox = (cx if cx is not None else bx + bw / 2) - (x0 + x1) / 2 * s + optical_dx * s
    oy = by + (bh - H) / 2 - y0 * s
    T = lambda q: (q[0] * s + ox, q[1] * s + oy)
    poly = lambda P: 'M' + 'L'.join(f'{f(a)} {f(b)}' for a, b in (T(q) for q in P)) + 'Z'
    return poly(bar) + poly(D), dict(scale=s, x0=x0 * s + ox, x1=x1 * s + ox, y0=y0 * s + oy, y1=y1 * s + oy,
                                     bar=[T(q) for q in bar], dot=[T(q) for q in D])
