"""App-icon preview sheet: home screens (light/dark/themed), mask shapes, sizes, notification."""
import os, json, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand as B
HERE = os.path.dirname(os.path.abspath(__file__)); D = os.path.abspath(os.path.join(HERE, '..'))
A = os.path.join(D, 'app-icon')
fg = open(os.path.join(A, 'svg', 'adaptive-foreground.svg')).read()
mono = open(os.path.join(A, 'svg', 'adaptive-monochrome.svg')).read()

def adaptive(size, radius='50%', themed=None):
    """Simulate launcher masking: layers are 108dp, visible window is 72dp (size)."""
    layer = size * 108 / 72; off = -(layer - size) / 2
    if themed:
        bgc, fgc = themed
        art = mono.replace('fill="#000000"', f'fill="{fgc}"')
    else:
        bgc, art = B.HALDI, fg
    art = art.replace('<svg ', f'<svg width="{layer}" height="{layer}" style="position:absolute;left:{off}px;top:{off}px" ')
    return f'<div class="ic" style="width:{size}px;height:{size}px;border-radius:{radius};background:{bgc}">{art}</div>'

# neutral placeholder apps (abstract, no real brands)
PH = [('#4C7DF0', 'circle'), ('#2BB673', 'sq'), ('#F2F2F2', 'tri'), ('#7A5AF8', 'ring'), ('#EE6C4D', 'bar'),
      ('#00A3A3', 'circle'), ('#3D3D3D', 'sq'), ('#F4B400', 'ring'), ('#9AA0A6', 'bar'), ('#E0E7FF', 'tri'),
      ('#1E88E5', 'ring'), ('#43A047', 'bar'), ('#5E35B1', 'circle'), ('#F06292', 'sq'), ('#795548', 'tri'),
      ('#26C6DA', 'bar'), ('#8D6E63', 'circle'), ('#AB47BC', 'ring'), ('#FFFFFF', 'sq')]
def ph(c, k, size, themed=None):
    bg = themed[0] if themed else c
    g = themed[1] if themed else ('#FFFFFF' if c not in ('#F2F2F2', '#E0E7FF', '#FFFFFF') else '#555')
    shape = {'circle': f'<circle cx="50" cy="50" r="18" fill="{g}"/>', 'sq': f'<rect x="33" y="33" width="34" height="34" rx="6" fill="{g}"/>',
             'tri': f'<path d="M50 30 L70 68 L30 68 Z" fill="{g}"/>', 'ring': f'<circle cx="50" cy="50" r="17" fill="none" stroke="{g}" stroke-width="7"/>',
             'bar': f'<rect x="30" y="44" width="40" height="12" rx="6" fill="{g}"/>'}[k]
    return f'<div class="ic" style="width:{size}px;height:{size}px;border-radius:50%;background:{bg}"><svg viewBox="0 0 100 100" width="{size}" height="{size}">{shape}</svg></div>'

def phone(title, wall, label_col, themed=None, dark=False):
    names = ['Maps', 'Wallet', 'Notes', 'Clock', 'Music', 'Camera', 'Files', 'Photos', 'Sale Lagi Hai!', 'Weather',
             'Mail', 'Calendar', 'Store', 'Chat', 'Books', 'Fit', 'Radio', 'Podcasts', 'Settings', 'Contacts']
    cells = ''
    j = 0
    for i, n in enumerate(names):
        if n.startswith('Sale'):
            ic = adaptive(54, themed=themed)
        else:
            c, k = PH[j % len(PH)]; j += 1
            ic = ph(c, k, 54, themed)
        cells += f'<div class="cell">{ic}<span style="color:{label_col}">{n if len(n) < 12 else "Sale Lagi H…"}</span></div>'
    dock = ''.join(adaptive(54, themed=themed) if i == 2 else ph(*PH[i + 3], 54, themed) for i in range(4))
    return f'''<div class="phone"><div class="screen" style="background:{wall}">
      <div class="sb" style="color:{label_col}">9:41 <span style="float:right">5G ▮▮▮</span></div>
      <div class="grid">{cells}</div>
      <div class="dock">{dock}</div></div><div class="cap">{title}</div></div>'''

def build():
    L_WALL = 'linear-gradient(160deg,#F4E9DA 0%,#E9D9C6 55%,#D9C3AE 100%)'
    D_WALL = 'linear-gradient(160deg,#20263A 0%,#141826 60%,#0B0D14 100%)'
    themed_light = ('#DCE2F9', '#2A3C78'); themed_dark = ('#2C3142', '#C6D0F4')
    shapes = ''.join(f'<div class="sh">{adaptive(96, r)}<span>{n}</span></div>' for n, r in
                     [('circle', '50%'), ('squircle', '30%'), ('rounded sq.', '18%'), ('teardrop', '50% 50% 50% 12%')])
    sizes = ''.join(f'<div class="sz">{adaptive(s, "50%")}<span>{s}px</span></div>' for s in (96, 72, 48, 36, 24, 16))
    sizes_dark = ''.join(f'<div class="sz">{adaptive(s, "28%")}<span>{s}px</span></div>' for s in (96, 72, 48, 36, 24, 16))
    notif = f'''<div class="notif"><div class="nsb">9:41 <img src="{A}/png/notification/ic_stat_sale-xxhdpi-72.png" width=18 height=18 style="vertical-align:-3px;margin-left:6px"><img src="{A}/png/notification/ic_stat_sale-xxhdpi-72.png" width=18 height=18 style="vertical-align:-3px;margin-left:4px;opacity:.9"></div>
      <div class="ncard"><div class="nhead"><span class="nbadge"><img src="{A}/png/notification/ic_stat_sale-xxhdpi-72.png" width=14 height=14></span> Sale Lagi Hai! · now</div>
      <div class="ntitle">🔔 Sale Lagi Hai! Sapphire 40% off is live</div><div class="nbody">Dolmen Mall Clifton + online. Ends Sunday.</div></div></div>'''
    html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face{{font-family:Ins;src:url({D}/fonts/static/InstrumentSans-Regular.ttf)}}
    @font-face{{font-family:Ins;font-weight:600;src:url({D}/fonts/static/InstrumentSans-SemiBold.ttf)}}
    @font-face{{font-family:Bri;src:url({D}/fonts/static/BricolageGrotesqueCondensed-ExtraBold.ttf)}}
    body{{margin:0;padding:36px;width:1528px;background:#FAF8F4;font-family:Ins;color:#1A1433}}
    h1{{font-family:Bri;font-size:40px;margin:0 0 4px}} p.s{{margin:0 0 24px;color:#5D5769}}
    .row{{display:flex;gap:28px;align-items:flex-start}}
    .phone{{width:300px}} .screen{{height:610px;border-radius:34px;padding:14px 14px;box-sizing:border-box;position:relative;border:8px solid #1A1433}}
    .cap{{text-align:center;margin-top:10px;font-weight:600;font-size:14px}}
    .sb{{font-size:12px;font-weight:600;margin:0 8px 28px}}
    .grid{{display:grid;grid-template-columns:repeat(4,1fr);row-gap:18px}}
    .cell{{display:flex;flex-direction:column;align-items:center;gap:5px}} .cell span{{font-size:10.5px;white-space:nowrap}}
    .dock{{position:absolute;bottom:22px;left:22px;right:22px;display:flex;justify-content:space-between;padding:10px 12px;border-radius:30px;background:rgba(255,255,255,.18)}}
    .ic{{position:relative;overflow:hidden;flex:none}}
    .panel{{background:#fff;border-radius:16px;padding:20px;border:1px solid #E3DFD9}} .panel h3{{margin:0 0 14px;font-size:14px}}
    .sh,.sz{{display:inline-flex;flex-direction:column;align-items:center;gap:6px;margin-right:16px;font-size:11px;color:#5D5769;vertical-align:bottom}}
    .notif{{background:#1E2230;border-radius:16px;padding:12px;width:430px;color:#fff}} .nsb{{font-size:12px;font-weight:600;margin-bottom:10px}}
    .ncard{{background:#2C3142;border-radius:14px;padding:12px 14px}} .nhead{{font-size:11px;opacity:.8;margin-bottom:6px}}
    .nbadge{{display:inline-flex;width:20px;height:20px;border-radius:50%;background:#B78100;align-items:center;justify-content:center;vertical-align:-6px;margin-right:4px}}
    .ntitle{{font-weight:600;font-size:14px}} .nbody{{font-size:13px;opacity:.85;margin-top:2px}}
    </style></head><body>
    <h1>App icon preview</h1><p class="s">Adaptive icon simulated: 108dp layers under a 72dp launcher mask. Themed rows use the monochrome layer tinted by the system.</p>
    <div class="row">
      {phone('Light wallpaper', L_WALL, '#2A2235')}
      {phone('Dark wallpaper', D_WALL, '#F2EFEA')}
      {phone('Themed icons (Android 13+), light', 'linear-gradient(160deg,#EEF1FB,#D7DDF1)', '#2A3C78', themed_light)}
      {phone('Themed icons, dark', 'linear-gradient(160deg,#1A1D27,#0E1016)', '#C6D0F4', themed_dark, True)}
    </div>
    <div class="row" style="margin-top:28px">
      <div class="panel" style="flex:1"><h3>OEM mask shapes (same layers)</h3>{shapes}</div>
      <div class="panel" style="flex:1"><h3>Small sizes on light</h3>{sizes}</div>
    </div>
    <div class="row" style="margin-top:20px">
      <div class="panel" style="flex:1;background:#141826;border-color:#141826;color:#F2EFEA"><h3>Small sizes on dark</h3>{sizes_dark}</div>
      <div class="panel" style="flex:1"><h3>Notification: small icon (white silhouette) + accent</h3>{notif}</div>
    </div>
    </body></html>'''
    hp = os.path.join(HERE, '.preview.html'); open(hp, 'w').write(html)
    jf = os.path.join(HERE, '.pj.json')
    json.dump([dict(html=hp, out=os.path.join(A, 'preview-sheet.png'), w=1600, h=1200, full=True, wait=800)], open(jf, 'w'))
    subprocess.run(['node', os.path.join(HERE, 'render.js'), jf], check=True)
    os.remove(jf); os.remove(hp)
if __name__ == '__main__':
    build()
