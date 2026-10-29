"""Logo concept generator: four genuinely different directions, written as vector paths."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from textpath import text_path

FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'fonts', 'variable')
BRI = os.path.join(FONTS, 'BricolageGrotesque[opsz,wdth,wght].ttf')
OUT = os.path.join(os.path.dirname(__file__), '..', 'logo', 'concepts')

HALDI, INK, PAPER, CHILI = '#FFC414', '#1A1433', '#FFF8E7', '#E8352B'

def f(v): return f'{v:.2f}'.rstrip('0').rstrip('.')
def poly(pts): return 'M' + ' L'.join(f'{f(x)} {f(y)}' for x, y in pts) + ' Z'

# ---------- Concept A: Qalam Bang (alif + nuqta) ----------
# Exploration history: qalam.py (parametric nib sweeps, rejected: read as blades / "//")
# Final hand-placed geometry lives in brand.py.
import brand
def concept_a_symbol(fg, bg=None, size=100):
    return brand.symbol_svg(fg, bg, size, mark_h=74)

# ---------- Concept B: Bang Bubble (word of mouth) ----------
def bubble_bang():
    # pill bar that is also a speech bubble (tail bottom-left), round dot
    bar = ('M50 6 C58.8 6 63 11 63 19 L63 49 C63 57.5 58 62 50 62 L44 62 L33 71 L36.5 60.5 '
           'C33 58 37 54.5 37 49 L37 19 C37 11 41.2 6 50 6 Z')
    bar = ('M50 6 C57.7 6 63 11.3 63 19 L63 48 C63 55.7 57.7 61 50 61 L46.5 61 L35 70.5 L38.4 57.2 '
           'C37.5 54.6 37 51.5 37 48 L37 19 C37 11.3 42.3 6 50 6 Z')
    dot = 'M50 74 a12 12 0 1 0 0.01 0 Z'
    return bar + ' ' + dot

def concept_b_symbol(fg, bg=None, size=100):
    bgr = f'<rect width="100" height="100" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}">{bgr}<path d="{bubble_bang()}" fill="{fg}"/></svg>'

# ---------- Concept C: Painted Banner (sign-painter block shadow) ----------
def concept_c_symbol(fg, shadow, bg=None, size=100):
    var = {'wght': 800, 'wdth': 75, 'opsz': 96}
    d, w, b = text_path(BRI, 'S!', 92, 0, 0, var)
    bx0, by0, bx1, by1 = b
    sx = 50 - (bx0 + bx1) / 2 - 3; sy = 50 - (by0 + by1) / 2 - 3
    bgr = f'<rect width="100" height="100" fill="{bg}"/>' if bg else ''
    # block shadow: same outline stepped down-right (extruded, sign-painter style)
    steps = ''.join(f'<path d="{d}" transform="translate({f(sx+i*0.75)} {f(sy+i*0.75)})" fill="{shadow}"/>' for i in range(1, 9))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}">{bgr}{steps}'
            f'<path d="{d}" transform="translate({f(sx)} {f(sy)})" fill="{fg}"/></svg>')

# ---------- Concept D: Shutter Up (bazaar shutter, bang in negative space) ----------
def concept_d_symbol(fg, bg=None, size=100):
    bgr = f'<rect width="100" height="100" fill="{bg}"/>' if bg else ''
    slats = ''
    for i in range(6):
        y = 12 + i * 11.5
        slats += f'<rect x="14" y="{f(y)}" width="72" height="8" rx="1.5"/>'
    # shutter raised: light gap at the bottom with a bang knocked out
    mask = ('<mask id="m"><rect width="100" height="100" fill="#fff"/>'
            '<rect x="43" y="8" width="14" height="50" rx="7" fill="#000"/><circle cx="50" cy="71" r="7.5" fill="#000"/></mask>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}">{bgr}'
            f'<defs>{mask}</defs><g fill="{fg}" mask="url(#m)">{slats}<rect x="10" y="84" width="80" height="5" rx="2.5"/></g></svg>')

SYMBOLS = {
    'A_qalam_bang': lambda fg, bg=None, size=100, **k: concept_a_symbol(fg, bg, size),
    'B_bang_bubble': lambda fg, bg=None, size=100, **k: concept_b_symbol(fg, bg, size),
    'C_painted_banner': lambda fg, bg=None, size=100, shadow=None, **k: concept_c_symbol(fg, shadow or fg, bg, size),
    'D_shutter_up': lambda fg, bg=None, size=100, **k: concept_d_symbol(fg, bg, size),
}

# ---------- Wordmarks per concept ----------
def wm_a(fg):
    var = {'wght': 800, 'wdth': 75, 'opsz': 96}
    size = 100
    d, w, b = text_path(BRI, 'Sale Lagı Haı', size, 0, 0, var, tracking=-6)
    # i-dots replaced by nuqta diamonds; bang drawn by hand
    from textpath import shape
    out = f'<path d="{d}" fill="{fg}"/>'
    bang, _ = qalam_bang(cx=0, top=0, height=74)
    out += f'<path d="{bang}" transform="translate({f(w+20)} -71)" fill="{fg}"/>'
    return out, w + 44, -78, 10

def wm_c(fg, shadow):
    var = {'wght': 800, 'wdth': 75, 'opsz': 96}
    lines = ['SALE', 'LAGI', 'HAI!']
    out = ''; y = 0
    for ln in lines:
        d, w, b = text_path(BRI, ln, 80, 0, y, var, tracking=10)
        out += ''.join(f'<path d="{d}" transform="translate({f(i*0.7)} {f(i*0.7)})" fill="{shadow}"/>' for i in range(1, 7))
        out += f'<path d="{d}" fill="{fg}"/>'
        y += 74
    return out

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for k, fn in SYMBOLS.items():
        with open(os.path.join(OUT, f'{k}.svg'), 'w') as fh:
            fh.write(fn(INK, HALDI, 512, shadow=PAPER) if k != 'C_painted_banner' else fn(PAPER, HALDI, 512, shadow=INK))
    print('ok')
