"""One-page brand board: design/brand-board.html -> design/brand-board.png"""
import json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand as B
import build_tokens as T

HERE = os.path.dirname(os.path.abspath(__file__)); D = os.path.abspath(os.path.join(HERE, '..'))

def construction_svg():
    """Large Qalam Bang with its construction: nib-angle cut, alif, nuqta unit, gap."""
    d = B.bang(4, 0, 0)  # 400-unit space
    bar = [(x * 4, y * 4) for x, y in B.BAR]
    cx, cy, r, _ = B.DOT; cx, cy, r = cx * 4, cy * 4, r * 4
    TL, TR = bar[0], bar[1]
    # extend the nib-cut line
    dx, dy = TR[0] - TL[0], TR[1] - TL[1]
    ext = [(TL[0] - dx * 0.9, TL[1] - dy * 0.9), (TR[0] + dx * 0.9, TR[1] + dy * 0.9)]
    # a nuqta-parallel line on the dot's upper-left edge
    n_top, n_left = (cx, cy - r), (cx - r, cy)
    ink = B.SURMA; red = B.MIRCH; blue = '#3B3FD9'
    return f'''<svg viewBox="70 -10 380 420" width="340" height="376" xmlns="http://www.w3.org/2000/svg">
      <path d="{d}" fill="{ink}"/>
      <line x1="{ext[0][0]}" y1="{ext[0][1]}" x2="{ext[1][0]}" y2="{ext[1][1]}" stroke="{red}" stroke-width="1.5" stroke-dasharray="5 4"/>
      <text x="{ext[1][0] - 62}" y="{ext[1][1] + 4}" font-size="18" fill="{red}" font-family="Ins">nib angle</text>
      <line x1="{n_left[0] - 30}" y1="{n_left[1] + 30}" x2="{n_top[0] + 30}" y2="{n_top[1] - 30}" stroke="{red}" stroke-width="1.5" stroke-dasharray="5 4"/>
      <rect x="{cx - r}" y="{cy - r}" width="{2 * r}" height="{2 * r}" fill="none" stroke="{blue}" stroke-width="1"/>
      <text x="{cx + r + 8}" y="{cy + 4}" font-size="18" fill="{blue}" font-family="Ins">nuqta = 1 unit</text>
      <text x="{bar[2][0] + 12}" y="{(TR[1] + bar[4][1]) / 2}" font-size="18" fill="{blue}" font-family="Ins">alif</text>
      <text x="{bar[2][0] + 12}" y="{(TR[1] + bar[4][1]) / 2 + 16}" font-size="15" fill="#5D5769" font-family="Ins">cut, full nib, pen lifts</text>
      <line x1="{bar[4][0] + 28}" y1="{bar[4][1]}" x2="{bar[4][0] + 28}" y2="{cy - r}" stroke="{blue}" stroke-width="1"/>
      <text x="{bar[4][0] + 34}" y="{(bar[4][1] + cy - r) / 2 + 4}" font-size="15" fill="#5D5769" font-family="Ins">gap 0.35</text>
    </svg>'''

def swatch(name, hexv, sub, fg, contrast):
    return (f'<div class="sw" style="background:{hexv};color:{fg}"><b>{name}</b><span>{hexv}</span>'
            f'<small>{sub}</small><em>{contrast}</em></div>')

def build():
    P = T.PALETTE
    r = lambda a, b: f'{T.ratio(a, b):.1f}:1'
    scale = ''.join(f'<div style="background:{v};color:{"#1A1433" if T.lum(v) > 0.2 else "#FAF8F4"}">{k}</div>'
                    for k, v in P['surma'].items())
    html = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Sale Lagi Hai! brand board</title>
<style>
@font-face{{font-family:Bri;src:url(fonts/static/BricolageGrotesqueCondensed-ExtraBold.ttf)}}
@font-face{{font-family:BriB;src:url(fonts/static/BricolageGrotesque-Bold.ttf)}}
@font-face{{font-family:Ins;src:url(fonts/static/InstrumentSans-Regular.ttf)}}
@font-face{{font-family:Ins;font-weight:600;src:url(fonts/static/InstrumentSans-SemiBold.ttf)}}
@font-face{{font-family:Nas;src:url(fonts/static/NotoNastaliqUrdu-Regular.ttf)}}
@font-face{{font-family:Nas;font-weight:700;src:url(fonts/static/NotoNastaliqUrdu-Bold.ttf)}}
:root{{--haldi:#FFC414;--surma:#1A1433;--kaghaz:#FFF8E7;--neel:#3B3FD9;--mirch:#DC2E24;--n50:#FAF8F4;--n600:#5D5769;--n200:#E3DFD9}}
*{{box-sizing:border-box}} body{{margin:0;width:1600px;background:var(--n50);font-family:Ins;color:var(--surma)}}
.wrap{{padding:48px}} .g{{display:grid;gap:20px}} .card{{background:#fff;border:1px solid var(--n200);border-radius:16px;padding:24px;overflow:hidden}}
h2{{font:800 13px Ins;letter-spacing:.12em;text-transform:uppercase;color:var(--n600);margin:0 0 16px}}
.hero{{background:var(--kaghaz);border-radius:20px;padding:44px 48px;display:flex;align-items:center;justify-content:space-between}}
.hero .tag{{font-family:BriB;font-size:26px;margin-top:14px}} .hero .ur{{font-family:Nas;font-size:22px;direction:rtl;line-height:2.1;color:var(--n600)}}
.idea p{{font-size:15px;line-height:1.5;margin:0 0 10px;max-width:460px}} .idea .big{{font-family:Bri;font-size:44px;line-height:1;margin:0 0 14px}}
.sw{{border-radius:12px;padding:16px;height:150px;display:flex;flex-direction:column;gap:2px;font-size:13px}} .sw b{{font-family:Bri;font-size:24px;font-weight:400}}
.sw small{{opacity:.8}} .sw em{{margin-top:auto;font-style:normal;font-weight:600;font-size:12px}}
.scale{{display:grid;grid-template-columns:repeat(12,1fr);border-radius:10px;overflow:hidden;margin-top:12px}} .scale div{{height:46px;font-size:11px;padding:6px}}
.tile{{display:flex;gap:18px;align-items:center;flex-wrap:wrap}}
.dark{{background:var(--surma);color:var(--n50);border-color:var(--surma)}}
.spec .a{{font-family:Bri;font-size:64px;line-height:1}} .spec .b{{font-family:Ins;font-size:16px;line-height:1.5;max-width:420px}}
.spec .u{{font-family:Nas;font-size:22px;line-height:2.1;direction:rtl}} .spec .lbl{{font-size:12px;color:var(--n600);margin:14px 0 2px}}
.deal{{border-radius:12px;overflow:hidden;border:1px solid var(--n200);background:#fff;width:300px}}
.deal .img{{height:120px;background:repeating-linear-gradient(135deg,#F2EFEA 0 10px,#EAE6DF 10px 20px);position:relative}}
.badge{{position:absolute;left:12px;top:12px;background:var(--mirch);color:#fff;font-family:Bri;font-size:18px;padding:4px 8px;border-radius:4px;letter-spacing:.02em}}
.feat{{position:absolute;right:12px;top:12px;background:var(--haldi);color:var(--surma);font:600 11px Ins;padding:5px 8px;border-radius:4px}}
.deal .body{{padding:12px 14px}} .deal .t{{font-family:BriB;font-size:19px}} .deal .m{{font-size:12px;color:var(--n600);margin-top:2px}}
.deal .p{{font-family:Bri;font-size:26px;margin-top:6px;font-feature-settings:"tnum"}} .deal .p s{{font-family:Ins;font-size:13px;color:var(--n600);margin-left:6px}}
.deal.dk{{background:#1A1433;border-color:#2C263A;color:#FAF8F4}} .deal.dk .img{{background:repeating-linear-gradient(135deg,#2C263A 0 10px,#241E33 10px 20px)}}
.deal.dk .m,.deal.dk .p s{{color:#A29DA6}} .deal.dk .badge{{background:#FF6B5E;color:#0F0B1F}}
.btn{{display:inline-block;font:600 15px Ins;padding:12px 20px;border-radius:8px;margin:12px 8px 0 0}}
.push{{background:#2C3142;color:#fff;border-radius:14px;padding:12px 14px;font-size:13px;width:330px}} .push b{{display:block;font-size:14px;margin:4px 0 2px}}
.voice td{{padding:7px 10px;border-top:1px solid var(--n200);font-size:13px;vertical-align:top}} .voice .u{{font-family:Nas;direction:rtl;font-size:15px;line-height:2}}
.dont{{font-size:13px;line-height:1.7;margin:0;padding-left:18px}}
</style></head><body><div class="wrap g">

<div class="hero"><div><img src="logo/svg/lockup-horizontal-ink.svg" width="720" alt="Sale Lagi Hai! horizontal lockup">
  <div class="tag">Sale ki khabar, sab se pehle. &nbsp;<span style="color:var(--n600);font-family:Ins;font-size:18px">First to know when the sale is on.</span></div></div>
  <div style="text-align:right"><img src="logo/svg/urdu-wordmark-ink.svg" height="120" alt="Urdu wordmark"><div class="ur">سیل کی خبر، سب سے پہلے۔</div></div></div>

<div class="g" style="grid-template-columns:1.25fr 1fr 1fr">
  <div class="card idea" style="display:flex;gap:20px;align-items:center">{construction_svg()}
    <div><h2>The idea</h2><div class="big">The shout, written properly.</div>
    <p>"Sale lagi hai!" is something people shout. Our exclamation mark is written the way a calligrapher writes
    with a reed pen: the bar is a Nastaliq <b>alif</b>, the dot is a <b>nuqta</b>, the unit of calligraphic proportion.</p>
    <p>A bold "!" to everyone; the hand of the Urdu script to Urdu readers. Loud, but well-made.</p></div></div>
  <div class="card"><h2>Mark &amp; versions</h2><div class="tile">
    <img src="logo/svg/symbol-tile.svg" width="96"><img src="logo/svg/symbol-tile-dark.svg" width="96"><img src="logo/svg/symbol-tile-black.svg" width="96">
    <img src="logo/svg/symbol-ink.svg" width="64"><img src="logo/svg/symbol-tile.svg" width="32"><img src="logo/svg/symbol-tile.svg" width="16"></div>
    <div style="margin-top:18px"><img src="logo/svg/wordmark-black.svg" width="300"></div>
    <div style="margin-top:10px"><img src="logo/svg/lockup-bilingual-ink.svg" width="220"></div></div>
  <div class="card dark"><h2 style="color:#A29DA6">On dark</h2>
    <img src="logo/svg/lockup-horizontal-on-dark.svg" width="380"><div style="margin-top:22px"><img src="logo/svg/urdu-wordmark-haldi.svg" height="78"></div>
    <div style="margin-top:22px;display:flex;gap:14px;align-items:center"><img src="app-icon/png/play-store-512.png" width="84" style="border-radius:26px">
    <img src="app-icon/png/play-store-512-alt-raat.png" width="84" style="border-radius:26px;outline:1px solid #433D50">
    <img src="app-icon/png/notification/ic_stat_sale-xxxhdpi-96.png" width="32"><span style="font-size:12px;color:#A29DA6">Play icon · Raat alternate · notification</span></div>
    <div style="margin-top:26px"><img src="logo/svg/lockup-bilingual-white.svg" width="200"></div></div>
</div>

<div class="card"><h2>Colour</h2><div class="g" style="grid-template-columns:repeat(5,1fr);gap:14px">
  {swatch('Haldi', '#FFC414', 'turmeric · brand fill', '#1A1433', 'ink on it ' + r('#1A1433', '#FFC414'))}
  {swatch('Surma', '#1A1433', 'kohl ink · text, mark', '#FAF8F4', 'on paper ' + r('#1A1433', '#FAF8F4'))}
  {swatch('Kaghaz', '#FFF8E7', 'paper · behind the logo', '#1A1433', 'ink on it ' + r('#1A1433', '#FFF8E7'))}
  {swatch('Neel', '#3B3FD9', 'truck-art blue · links, focus', '#FFFFFF', 'white on it ' + r('#FFFFFF', '#3B3FD9'))}
  {swatch('Mirch', '#DC2E24', 'chilli · deal badges only', '#FFFFFF', 'white on it ' + r('#FFFFFF', '#DC2E24'))}
  </div><div class="scale">{scale}</div>
  <div style="font-size:12px;color:var(--n600);margin-top:10px">Semantic: success #18794E · warning #A34D00 · error #B42318 · info #3B3FD9. All 64 checked pairs pass WCAG 2.2 AA (tokens/contrast-report.md).</div></div>

<div class="g" style="grid-template-columns:1.1fr 1fr 0.9fr">
  <div class="card spec"><h2>Type</h2>
    <div class="lbl">Bricolage Grotesque ExtraBold Condensed · display, prices</div><div class="a">Flat 40% · Rs 2,999</div>
    <div class="lbl">Instrument Sans · UI and reading</div><div class="b">Sapphire's summer sale is live at Dolmen Mall Clifton and online. Ends Sunday, 11:59 pm. Rs 4,999 → Rs 2,999.</div>
    <div class="lbl">Noto Nastaliq Urdu · Urdu, line-height 2.1</div><div class="u">سفائر کی گرمیوں کی سیل شروع ہو گئی ہے۔ اتوار رات تک۔</div></div>
  <div class="card"><h2>In the app</h2><div style="display:flex;gap:14px">
    <div class="deal"><div class="img"><span class="badge">-40%</span><span class="feat">Featured</span></div><div class="body"><div class="t">Sapphire Summer Sale</div>
      <div class="m">Clifton · 2.1 km · ends Sun</div><div class="p">Rs 2,999<s>Rs 4,999</s></div></div></div>
    <div class="deal dk" style="width:200px"><div class="img"><span class="badge">-25%</span></div><div class="body"><div class="t">Kolachi · HBL</div>
      <div class="m">Do Darya · tonight</div><div class="p">25% off</div></div></div></div>
    <span class="btn" style="background:var(--haldi)">Set alert</span><span class="btn" style="border:1.5px solid #7B7585">Share on WhatsApp</span><span class="btn" style="color:var(--neel);padding-left:0">View terms</span>
    <div class="push" style="margin-top:14px"><span style="opacity:.75;font-size:11px">Sale Lagi Hai! · now</span><b>🔔 Sale Lagi Hai! Sapphire 40% off is live</b>Ends Sunday. Dolmen Mall Clifton + online.</div></div>
  <div class="card"><h2>Voice</h2><table class="voice" style="border-collapse:collapse;width:100%">
    <tr><td><b>We are</b> bazaar-smart, quick, honest, yaar, proudly local.</td></tr>
    <tr><td><b>We are not</b> spammy, "HURRY!!!", fake "up to 70%", kitsch.</td></tr>
    <tr><td>Quiet day in the bazaar. We'll shout when a sale starts.</td></tr>
    <tr><td>Bazaar aaj thanda hai. Sale lagi to hum bata denge.</td></tr>
    <tr><td class="u">بازار آج ٹھنڈا ہے۔ سیل لگی تو ہم بتا دیں گے۔</td></tr>
    <tr><td><b>Rule:</b> one exclamation mark per message, and it's ours.</td></tr></table>
    <h2 style="margin-top:16px">Don't</h2><ul class="dont"><li>gradients, glow, 3D, sparkles</li><li>round dots instead of nuqtas</li><li>"SALE"/% in the app icon</li><li>mirror the bang in RTL</li></ul></div>
</div>
</div></body></html>'''
    hp = os.path.join(D, 'brand-board.html'); open(hp, 'w').write(html)
    jf = os.path.join(HERE, '.bb.json')
    json.dump([dict(html=hp, out=os.path.join(D, 'brand-board.png'), w=1600, h=1400, full=True, wait=900)], open(jf, 'w'))
    subprocess.run(['node', os.path.join(HERE, 'render.js'), jf], check=True); os.remove(jf)

if __name__ == '__main__':
    build()
