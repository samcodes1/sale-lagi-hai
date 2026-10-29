"""Build a critique contact sheet for logo concepts: 512/48/16 px, light/dark/mono."""
import os, sys, json, subprocess
sys.path.insert(0, os.path.dirname(__file__))
import concepts as C
HERE = os.path.dirname(os.path.abspath(__file__))
TMP = os.environ.get('TMPDIR_SHEET', os.path.join(HERE, '.sheet_tmp'))
os.makedirs(TMP, exist_ok=True)

VARIANTS = {
    'light': dict(fg=C.INK, bg=C.HALDI, shadow=C.INK, cfg=C.PAPER),
    'dark': dict(fg=C.HALDI, bg=C.INK, shadow='#000000', cfg=C.HALDI),
    'mono': dict(fg='#000000', bg='#FFFFFF', shadow='#000000', cfg='#FFFFFF'),
}
def svg_for(k, v, size):
    p = VARIANTS[v]
    if k == 'C_painted_banner':
        if v == 'mono':
            return C.concept_c_symbol('#FFFFFF', '#000000', '#FFFFFF', size)
        return C.concept_c_symbol(p['cfg'], p['shadow'] if v == 'light' else '#000', p['bg'], size)
    return C.SYMBOLS[k](p['fg'], p['bg'], size)

def build(keys=None, name='sheet'):
    keys = keys or list(C.SYMBOLS)
    jobs = []
    for k in keys:
        for v in VARIANTS:
            for s in (512, 48, 16):
                sp = os.path.join(TMP, f'{k}_{v}_{s}.svg')
                open(sp, 'w').write(svg_for(k, v, s))
                jobs.append(dict(svg=sp, out=sp[:-4] + '.png', w=s, h=s))
    jf = os.path.join(TMP, 'jobs.json'); json.dump(jobs, open(jf, 'w'))
    subprocess.run(['node', os.path.join(HERE, 'render.js'), jf], check=True)
    rows = ''
    for k in keys:
        cells = ''
        for v in VARIANTS:
            b = f'{k}_{v}'
            cells += (f'<div class=c><img src="{b}_512.png" width=200 height=200><img src="{b}_48.png" width=48 height=48>'
                      f'<img src="{b}_16.png" width=16 height=16><img class=z src="{b}_16.png" width=64 height=64><span>{v}</span></div>')
        rows += f'<div class=r><h3>{k}</h3>{cells}</div>'
    html = f'''<html><head><style>body{{margin:16px;font:13px sans-serif;background:#ddd}}
.r{{display:flex;align-items:flex-end;gap:14px;margin-bottom:14px}} h3{{width:130px;font-size:13px}}
.c{{display:flex;align-items:flex-end;gap:10px;background:#fff;padding:8px}} .c span{{writing-mode:vertical-rl;color:#888}}
.z{{image-rendering:pixelated}}</style></head><body>{rows}</body></html>'''
    hp = os.path.join(TMP, f'{name}.html'); open(hp, 'w').write(html)
    out = os.path.join(TMP, f'{name}.png')
    jf2 = os.path.join(TMP, 'jobs2.json'); json.dump([dict(html=hp, out=out, w=1400, h=260 * len(keys) + 40, full=True, wait=500)], open(jf2, 'w'))
    subprocess.run(['node', os.path.join(HERE, 'render.js'), jf2], check=True)
    return out
if __name__ == '__main__':
    import shutil
    out = build(sys.argv[1:] or None)
    shutil.copy(out, os.path.join(HERE, '..', 'logo', 'concepts', 'concepts-sheet.png'))
    if 'TMPDIR_SHEET' not in os.environ:
        shutil.rmtree(TMP)
    print(out)
