# Logo concepts and critique

All four concepts were written as vector code (`design/_src/concepts.py`, `qalam.py`, `brand.py`) and rendered
with Playwright/Chromium. Renders reviewed:

- `concepts/concepts-sheet.png`: every concept at 512, 48 and 16 px (16 px also shown 4x, pixelated), on Haldi
  (light), on Surma ink (dark) and in one-color mono.
- `concepts/A-qalam-bang-iterations.png`: the parametric pen-sweep attempts that were rejected (see A below).
- `concepts/wordmark-options.png`: four wordmark settings at 620 / 120 / 72 px.
- Final checks after refinement: `../app-icon/preview-sheet.png` (launcher masks, themed, 96→16 px, notification).

Scores use the tests in `.claude/skills/brand-identity/SKILL.md` §3 (1 = fails, 5 = strong).

| | Idea | Simple | Distinct | Appropriate | Mono | 16 px | Masks | Script fit | Total |
|---|---|---|---|---|---|---|---|---|---|
| **A Qalam Bang** | 5 | 5 | 4 | 5 | 5 | 4 | 5 | 5 | **38** |
| B Bang Bubble | 4 | 5 | 2 | 4 | 5 | 5 | 5 | 2 | 32 |
| C Painted Banner (S!) | 3 | 3 | 3 | 4 | 2 | 2 | 4 | 2 | 23 |
| D Shutter Up | 4 | 1 | 4 | 3 | 3 | 1 | 3 | 2 | 21 |

---

## A. Qalam Bang (chosen)

**Idea.** The exclamation mark from the name, drawn the way a calligrapher writes with a reed pen: the bar is a
Nastaliq *alif* (top cut flat on the nib angle, full nib width, tapering as the pen lifts), the dot is a *nuqta*
(the diamond the same nib stamps, the traditional unit of calligraphic proportion). It reads as "!" to everyone and
as Urdu handwriting to Urdu readers. It is also the alert itself: the core product moment.

**Construction.** 100-unit grid. Bar from y 7 to 63, top cut rising ~33°, flanks are two cubic curves that hold the
width for the first ~40% then taper to a 3-unit tip. Nuqta: a square on its corner, half-diagonal 11.5, corners
softened by 1.5 (a reed is never razor sharp). Gap bar→nuqta ≈ 0.35 nuqta. The whole mark leans ~12° like a written
alif. In the wordmark it is widened ×1.2 and set taller than the caps (it is the shout); for the 24 px notification
icon an optical-size version is widened ×1.22.

**512 px.** Strongest of the four. The cut top and the curved flank read as a hand-made stroke, not a font
character. The diamond nuqta rhymes with the cut. No effects needed.
**48 px.** Clean silhouette; the lean and the diamond are still visible, which is what makes it ours and not a
generic "!".
**16 px.** Reads as "!" on both Haldi and ink. The taper is lost (becomes a wedge), the diamond becomes a 3 px
square. Acceptable: the mark degrades into a plain bang, never into noise.
**Dark.** Haldi on Surma is excellent (12:1) and has a night-market feel; offered as the alternate icon.
**Mono.** Perfect: it is a single flat silhouette. The themed-icon and notification versions are free.

**Iterations.** First attempt (`qalam.py`, parametric nib sweeps): bars with straight cuts and a "slice" nuqta read
as `//` or a lightning bolt; curved sweeps read as a blade/feather. Final geometry was placed by hand after studying
Noto Nastaliq Urdu's own alif and nuqta outlines. The Noto "!" already uses a diamond dot, which confirms the
nuqta is authentic Urdu punctuation; our difference is the alif bar.

**Weaknesses (honest).**
- A single "!" is not unique as a category of mark; distinctiveness rests on the alif cut, the lean and the diamond.
  Trademark search is needed before filing.
- Ink "!" on yellow is close to the visual language of **hazard/warning signs**. The calligraphic form and the lack of
  a triangle soften it, but some users may read the icon as "warning" at a glance. The Raat (ink) alternate avoids it.
- At 16 px the calligraphic detail disappears; the idea only lands at 32 px and up.

## B. Bang Bubble

**Idea.** The bar of the "!" is a speech bubble (tail at the bottom left): *someone is telling you* the sale is on.
Word of mouth, WhatsApp forwarding.
**512 / 48 / 16 px.** Very legible at every size, the tail survives to 48 px. Mono is perfect.
**Why not.** It looks like a chat app (WhatsApp, Messenger and many icon packs use bubbles). The rounded pill is the
most generic "!" shape there is, so distinctiveness relies on the tail alone. No connection to Urdu: the same mark
could be any English startup. Kept as a possible icon for the "share deal" action, not the brand.

## C. Painted Banner (S!)

**Idea.** Bazaar sign-painter lettering: condensed heavy caps "SALE / LAGI / HAI!" with the hand-painted offset block
shadow seen on shop boards and trucks. Symbol = "S!".
**512 px.** Most immediately "Pakistani bazaar" of the four; confident and loud.
**48 px.** The extruded shadow becomes a dark smear; "S!" still readable.
**16 px.** Fails: shadow and letters merge into a blob.
**Mono.** Breaks. The idea depends on two tones (letter + shadow); in one color you get either a plain "S!" set in a
stock font (generic) or only the shadow. Truck-art lettering also tips into kitsch quickly and dates.
**Kept from it:** the hard, unblurred offset "stamp" shadow is a token (`elevation.stamp`) for the logo tile and
badges on marketing.

## D. Shutter Up

**Idea.** The rolled steel shutter of a Pakistani shop going up = the shop opening = sale on. The "!" is knocked out
of the slats as negative space.
**512 px.** Clever and specific; only works once explained.
**48 px.** Starts to read as a striped square ("menu" or "server" icon).
**16 px.** Fails completely: stripes alias into grey, the negative "!" disappears.
**Mono.** Works technically, but the meaning is gone. Also, in Pakistan "shutter down" is strongly associated with
strikes and closures, a mixed association for a cheerful brand.

---

## Decision

**A, the Qalam Bang**, refined into the final system in `design/logo/svg` and `design/logo/png`:

| File (svg/ and png/) | What |
|---|---|
| `symbol-{ink,haldi,black,white}` | The bare mark |
| `symbol-tile`, `symbol-tile-dark`, `symbol-tile-black` | Primary mark on its tile (avatar, favicon, social) |
| `wordmark-{ink,haldi,black,white}` | "Sale Lagi Hai!", Bricolage Grotesque ExtraBold 75% width converted to outlines, i-dots replaced by nuqtas, hand-drawn bang |
| `urdu-wordmark-*` | "سیل لگی ہے" shaped with HarfBuzz from Noto Nastaliq Urdu Bold, outlined, + Qalam Bang at the end (left) |
| `lockup-bilingual-*` | English over Urdu |
| `lockup-horizontal-{ink,on-dark,black,white}` | Tile + wordmark |

The Urdu outlines were checked against a browser rendering of the same string with the same font: both nuqtas of
the medial ی in سیل, the gaf's second stroke, the initial ہ with its Nastaliq hook mark, and the yeh barree are
present. A native reader should still sign off (see guidelines).
