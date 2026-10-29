"""Builds every final logo and app-icon asset from brand.py.
Run from anywhere:  python3 design/_src/build_final.py
Outputs SVG sources + PNG exports (via Playwright/Chromium) + Android VectorDrawable XML."""
import json, math, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand as B
from brand import f

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.abspath(os.path.join(HERE, '..'))
LOGO = os.path.join(D, 'logo'); ICON = os.path.join(D, 'app-icon')
JOBS = []

def save(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w').write(text)

def png(svg_path, out, w, h=None, transparent=True):
    JOBS.append(dict(svg=svg_path, out=out, w=w, h=h or w, transparent=transparent))

def svg_wrap(vb, inner, w=None, h=None):
    size = f' width="{f(w)}" height="{f(h)}"' if w else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{" ".join(f(v) for v in vb)}"{size}>{inner}</svg>'

# ------------------------------------------------------------------ geometry helpers
X0, Y0, X1, Y1 = B.BANG_BOUNDS
BW, BH = X1 - X0, Y1 - Y0
NUDGE = 0.014  # optical: the nuqta hangs left, so the whole mark shifts right by 1.4% of its height

def bang_in(cx, cy, h, wx=1.0):
    """Bang of height h centred (bbox) on cx,cy. wx widens it (optical-size variant for tiny sizes)."""
    sy = h / BH; sx = sy * wx
    tx = cx + NUDGE * h - (X0 + X1) / 2 * sx
    ty = cy - (Y0 + Y1) / 2 * sy
    return B.bang(sx, tx, ty, sy)

# ------------------------------------------------------------------ 1. logo
def build_logo():
    sv = os.path.join(LOGO, 'svg'); pv = os.path.join(LOGO, 'png')
    colours = {'ink': B.SURMA, 'haldi': B.HALDI, 'black': '#000000', 'white': '#FFFFFF', 'paper': B.KAGHAZ}

    # 1a. symbol (bare bang) on a square artboard, 10% padding
    for name, c in colours.items():
        if name == 'paper': continue
        p = os.path.join(sv, f'symbol-{name}.svg')
        save(p, svg_wrap((0, 0, 100, 100), f'<path fill="{c}" d="{bang_in(50, 50, 80)}"/>'))
        png(p, os.path.join(pv, f'symbol-{name}-1024.png'), 1024)

    # 1b. symbol tile (the primary mark as it lives on screens): Haldi tile, ink bang. + dark + mono
    tiles = {'tile': (B.HALDI, B.SURMA), 'tile-dark': (B.SURMA, B.HALDI), 'tile-black': ('#000000', '#FFFFFF')}
    for name, (bg, fg) in tiles.items():
        p = os.path.join(sv, f'symbol-{name}.svg')
        save(p, svg_wrap((0, 0, 100, 100), f'<rect width="100" height="100" rx="22.5" fill="{bg}"/>'
                                           f'<path fill="{fg}" d="{bang_in(50, 50, 66)}"/>'))
        png(p, os.path.join(pv, f'symbol-{name}-1024.png'), 1024)

    # 1c. English wordmark
    inner, w, cap = B.wordmark_paths(tracking=-10, bang_h=80, bang_wx=1.2)
    top, bottom = -82, 18  # cap/bang overshoot to g descender
    pad = 0
    vb = (0, top, w, bottom - top)
    WM = dict(inner=inner, w=w, top=top, bottom=bottom)
    for name, c in colours.items():
        if name == 'paper': continue
        p = os.path.join(sv, f'wordmark-{name}.svg')
        save(p, svg_wrap(vb, f'<g fill="{c}">{inner}</g>'))
        png(p, os.path.join(pv, f'wordmark-{name}-2000w.png'), 2000, round(2000 * (bottom - top) / w))

    # 1d. Urdu wordmark (outlined Noto Nastaliq Urdu Bold, shaped by HarfBuzz, + Qalam Bang)
    uinner, ux0, ux1, uy0, uy1 = B.urdu_paths(100)
    uvb = (ux0, uy0, ux1 - ux0, uy1 - uy0)
    UR = dict(inner=uinner, x0=ux0, x1=ux1, y0=uy0, y1=uy1)
    for name, c in colours.items():
        if name == 'paper': continue
        p = os.path.join(sv, f'urdu-wordmark-{name}.svg')
        save(p, svg_wrap(uvb, f'<g fill="{c}">{uinner}</g>'))
        png(p, os.path.join(pv, f'urdu-wordmark-{name}-1600w.png'), 1600, round(1600 * uvb[3] / uvb[2]))

    # 1e. Bilingual stacked lockup: English over Urdu, centred, rule-free
    def stacked(fg):
        sw = w; ush = 0.78  # Urdu scaled so its optical size matches the caps
        uw = (ux1 - ux0) * ush
        gap = 26
        H = (bottom - top) + gap + (uy1 - uy0) * ush
        W = max(sw, uw)
        g1 = f'<g transform="translate({f((W - sw) / 2)} {f(-top)})">{inner}</g>'
        g2 = f'<g transform="translate({f((W - uw) / 2 - ux0 * ush)} {f((bottom - top) + gap - uy0 * ush)}) scale({ush})">{uinner}</g>'
        return svg_wrap((0, 0, W, H), f'<g fill="{fg}">{g1}{g2}</g>'), W, H
    for name, c in colours.items():
        if name == 'paper': continue
        s_, W, H = stacked(c)
        p = os.path.join(sv, f'lockup-bilingual-{name}.svg'); save(p, s_)
        png(p, os.path.join(pv, f'lockup-bilingual-{name}-1600w.png'), 1600, round(1600 * H / W))

    # 1f. Horizontal lockup: tile + wordmark. Tile height = cap height x 1.55, gap = 0.36 tile.
    def horizontal(tile_bg, tile_fg, word_fg):
        T = 104; gap = 34
        cap_mid = -36  # optical middle of the caps/x-height zone
        ty = cap_mid - T / 2
        tile = (f'<rect x="0" y="{f(ty)}" width="{T}" height="{T}" rx="{f(T * 0.225)}" fill="{tile_bg}"/>'
                f'<path fill="{tile_fg}" d="{bang_in(T / 2, ty + T / 2, T * 0.66)}"/>')
        word = f'<g transform="translate({T + gap} 0)" fill="{word_fg}">{inner}</g>'
        y0 = min(ty, top); y1 = max(ty + T, bottom)
        W = T + gap + w
        return svg_wrap((0, y0, W, y1 - y0), tile + word), W, y1 - y0
    for name, (tb, tf, wf) in {'ink': (B.HALDI, B.SURMA, B.SURMA), 'on-dark': (B.HALDI, B.SURMA, B.KAGHAZ),
                               'black': ('#000000', '#FFFFFF', '#000000'), 'white': ('#FFFFFF', '#000000', '#FFFFFF')}.items():
        s_, W, H = horizontal(tb, tf, wf)
        p = os.path.join(sv, f'lockup-horizontal-{name}.svg'); save(p, s_)
        png(p, os.path.join(pv, f'lockup-horizontal-{name}-2000w.png'), 2000, round(2000 * H / W))
    return WM, UR

# ------------------------------------------------------------------ 2. app icons
DP = 4  # xxxhdpi px per dp
def build_icons():
    sv = os.path.join(ICON, 'svg'); pv = os.path.join(ICON, 'png'); xv = os.path.join(ICON, 'android-res')
    MARK_DP = 50          # bang height in dp on the 108dp adaptive canvas (max radius 27.2dp < 33dp safe zone)
    # Play Store 512 full bleed
    p = os.path.join(sv, 'play-store-512.svg')
    save(p, svg_wrap((0, 0, 512, 512), f'<rect width="512" height="512" fill="{B.HALDI}"/>'
                                       f'<path fill="{B.SURMA}" d="{bang_in(256, 256, 512 * MARK_DP / 72 * 0.94)}"/>'))
    png(p, os.path.join(pv, 'play-store-512.png'), 512, transparent=False)
    # Alternate for the owner to consider (see BRAND_GUIDELINES: hazard-sign risk of black-on-yellow)
    p = os.path.join(sv, 'play-store-512-alt-raat.svg')
    save(p, svg_wrap((0, 0, 512, 512), f'<rect width="512" height="512" fill="{B.SURMA}"/>'
                                       f'<path fill="{B.HALDI}" d="{bang_in(256, 256, 512 * MARK_DP / 72 * 0.94)}"/>'))
    png(p, os.path.join(pv, 'play-store-512-alt-raat.png'), 512, transparent=False)

    # Adaptive layers, 108dp canvas (432px)
    C = 108
    fg = svg_wrap((0, 0, C, C), f'<path fill="{B.SURMA}" d="{bang_in(54, 54, MARK_DP)}"/>')
    bg = svg_wrap((0, 0, C, C), f'<rect width="{C}" height="{C}" fill="{B.HALDI}"/>')
    mono = svg_wrap((0, 0, C, C), f'<path fill="#000000" d="{bang_in(54, 54, MARK_DP * 0.92)}"/>')
    for n, s_ in {'adaptive-foreground': fg, 'adaptive-background': bg, 'adaptive-monochrome': mono}.items():
        p = os.path.join(sv, f'{n}.svg'); save(p, s_)
        png(p, os.path.join(pv, f'{n}-432.png'), 432, transparent=(n != 'adaptive-background'))
    # Safe-zone guide overlay (for review only)
    guide = svg_wrap((0, 0, C, C), f'<rect width="{C}" height="{C}" fill="{B.HALDI}"/>'
                                   f'<path fill="{B.SURMA}" d="{bang_in(54, 54, MARK_DP)}"/>'
                                   f'<rect x="18" y="18" width="72" height="72" fill="none" stroke="#3B3FD9" stroke-width="0.4" stroke-dasharray="1 1"/>'
                                   f'<circle cx="54" cy="54" r="33" fill="none" stroke="#DC2E24" stroke-width="0.5"/>'
                                   f'<circle cx="54" cy="54" r="36" fill="none" stroke="#3B3FD9" stroke-width="0.3"/>')
    p = os.path.join(sv, 'adaptive-safe-zone-guide.svg'); save(p, guide)
    png(p, os.path.join(pv, 'adaptive-safe-zone-guide-432.png'), 432, transparent=False)

    # Legacy launcher icons (pre-API 26): square tile with rounded corners and 1dp margin; plus round
    leg = svg_wrap((0, 0, 48, 48), f'<rect x="1" y="1" width="46" height="46" rx="10" fill="{B.HALDI}"/>'
                                   f'<path fill="{B.SURMA}" d="{bang_in(24, 24, 31)}"/>')
    rnd = svg_wrap((0, 0, 48, 48), f'<circle cx="24" cy="24" r="23" fill="{B.HALDI}"/>'
                                   f'<path fill="{B.SURMA}" d="{bang_in(24, 24, 30)}"/>')
    save(os.path.join(sv, 'legacy-launcher.svg'), leg); save(os.path.join(sv, 'legacy-launcher-round.svg'), rnd)
    for dens, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        png(os.path.join(sv, 'legacy-launcher.svg'), os.path.join(pv, 'legacy', f'ic_launcher-{dens}-{px}.png'), px)
        png(os.path.join(sv, 'legacy-launcher-round.svg'), os.path.join(pv, 'legacy', f'ic_launcher_round-{dens}-{px}.png'), px)

    # Notification small icon: white silhouette on transparent, 24dp canvas, 20dp live area.
    # Uses the widened optical-size bang (x1.22) so the bar survives at 24px.
    nt = svg_wrap((0, 0, 24, 24), f'<path fill="#FFFFFF" d="{bang_in(12, 12, 20.5, wx=1.22)}"/>')
    p = os.path.join(sv, 'notification-small-icon.svg'); save(p, nt)
    for dens, px in {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}.items():
        png(p, os.path.join(pv, 'notification', f'ic_stat_sale-{dens}-{px}.png'), px)

    # Android 12+ splash icon. No icon background: 288dp canvas, content inside a 192dp circle.
    # windowSplashScreenBackground = Haldi (light) / Surma (dark)
    S = 288
    for n, (bgc, fgc) in {'splash-icon-light': (None, B.SURMA), 'splash-icon-dark': (None, B.HALDI)}.items():
        s_ = svg_wrap((0, 0, S, S), f'<path fill="{fgc}" d="{bang_in(S / 2, S / 2, 150)}"/>')
        p = os.path.join(sv, f'{n}.svg'); save(p, s_)
        png(p, os.path.join(pv, f'{n}-1152.png'), S * DP)
    sg = svg_wrap((0, 0, S, S), f'<rect width="{S}" height="{S}" fill="{B.HALDI}"/><path fill="{B.SURMA}" d="{bang_in(S / 2, S / 2, 150)}"/>'
                               f'<circle cx="144" cy="144" r="96" fill="none" stroke="#DC2E24" stroke-width="1"/>')
    p = os.path.join(sv, 'splash-safe-zone-guide.svg'); save(p, sg)
    png(p, os.path.join(pv, 'splash-safe-zone-guide-576.png'), 576, transparent=False)

    # Android VectorDrawable XML (drop into android/app/src/main/res/drawable/)
    def vd(name, w_dp, vb, path_d, color, comment):
        xml = (f'<?xml version="1.0" encoding="utf-8"?>\n<!-- {comment} -->\n'
               f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
               f'    android:width="{w_dp}dp" android:height="{w_dp}dp"\n'
               f'    android:viewportWidth="{vb}" android:viewportHeight="{vb}">\n'
               f'    <path android:fillColor="{color}" android:pathData="{path_d}"/>\n</vector>\n')
        save(os.path.join(xv, 'drawable', f'{name}.xml'), xml)
    vd('ic_launcher_foreground', 108, 108, bang_in(54, 54, MARK_DP), B.SURMA, 'Adaptive icon foreground. Mark max radius 27.2dp inside the 33dp safe zone.')
    vd('ic_launcher_monochrome', 108, 108, bang_in(54, 54, MARK_DP * 0.92), '#FF000000', 'Themed icon (Android 13+). System tints it; only alpha matters.')
    vd('ic_stat_sale', 24, 24, bang_in(12, 12, 20.5, wx=1.22), '#FFFFFFFF', 'Notification small icon. White silhouette; system tints it.')
    vd('splash_icon', 288, 288, bang_in(144, 144, 150), B.SURMA, 'Android 12 splash icon (no icon background). Content inside the 192dp circle.')
    save(os.path.join(xv, 'drawable', 'ic_launcher_background.xml'),
         '<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
         f'    <solid android:color="{B.HALDI}"/>\n</shape>\n')
    save(os.path.join(xv, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
         '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
         '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
         '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
         '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n</adaptive-icon>\n')
    save(os.path.join(xv, 'values', 'brand_colors.xml'),
         '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
         f'    <color name="brand_haldi">{B.HALDI}</color>\n    <color name="brand_surma">{B.SURMA}</color>\n'
         f'    <!-- notification accent: setColor(); shown behind the small icon -->\n'
         f'    <color name="notification_accent">#B78100</color>\n</resources>\n')
    save(os.path.join(xv, 'values-v31', 'splash_theme_snippet.xml'),
         '<?xml version="1.0" encoding="utf-8"?>\n<!-- Merge into your LaunchTheme (values-v31/styles.xml). Dark: use values-night-v31 with brand_surma and a Haldi icon. -->\n<resources>\n'
         '    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">\n'
         '        <item name="android:windowSplashScreenBackground">@color/brand_haldi</item>\n'
         '        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>\n'
         '    </style>\n</resources>\n')

def run_jobs():
    jf = os.path.join(HERE, '.jobs.json')
    for j in JOBS: os.makedirs(os.path.dirname(j['out']), exist_ok=True)
    json.dump(JOBS, open(jf, 'w'))
    subprocess.run(['node', os.path.join(HERE, 'render.js'), jf], check=True)
    os.remove(jf)

if __name__ == '__main__':
    build_logo(); build_icons(); run_jobs()
    print(len(JOBS), 'PNGs rendered')
