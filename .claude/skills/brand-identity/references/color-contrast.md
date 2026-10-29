# Color and contrast reference

## WCAG 2.x math (unchanged in 2.2)
Relative luminance of an sRGB color (8-bit channels → 0..1):

```
c = channel / 255
c_lin = c / 12.92                      if c <= 0.04045
      = ((c + 0.055) / 1.055) ^ 2.4    otherwise
L = 0.2126 R_lin + 0.7152 G_lin + 0.0722 B_lin
ratio = (L_lighter + 0.05) / (L_darker + 0.05)      range 1..21
```
(Before May 2021 the spec said 0.03928; it makes no practical difference.)

## Thresholds
| What | Level AA | Criterion |
|---|---|---|
| Body text, labels, placeholder that conveys info | 4.5:1 | 1.4.3 |
| Large text: ≥ 18 pt (≈ 24 px) or ≥ 14 pt bold (≈ 18.66 px) | 3:1 | 1.4.3 |
| UI component boundaries needed to find a control, focus indicators, state indicators (checked, selected) | 3:1 vs adjacent colors | 1.4.11 |
| Meaningful graphics (icons that carry meaning, chart marks) | 3:1 | 1.4.11 |
| Disabled controls, pure decoration, logos | exempt | |

Notes from the W3C Understanding docs:
- Treat thresholds as hard: 2.999:1 does not meet 3:1. Do not round before comparing.
- Thin lines and small shapes render lighter because of anti-aliasing; give thin elements extra margin.
- A control with visible, contrasting content (text or icon) does not need a contrasting boundary, but its focus
  indicator still does.
- Hue does not count; contrast is luminance only. Test color-blind safety separately (never rely on hue alone:
  pair red deal badges with a "-%" label, errors with an icon).

## Method
1. Define the palette (scales) and then **role maps** per theme (background, surface, text, primary, onPrimary…).
2. List every real pairing the UI will use (text on each surface, labels on each fill, borders, focus ring, badges).
3. Run a script over the list, print a table, fail CI on any regression.
4. Fixing a failing pair, in order of preference: darken/lighten the *text* color, change the role (e.g. a bright
   yellow becomes a fill with dark content), add a contrasting outline, enlarge to the large-text tier.
5. Dark theme: avoid pure black backgrounds and pure white text (halation); use ink ~#0F0B1F and off-white ~#FAF8F4.
   Desaturate and lighten accent colors for text on dark.
6. Shadows: tint with the ink color at low opacity; in dark theme use surface steps instead of shadows.

## Picking a distinctive primary
- List competitor primaries and the category's default color (deals and retail in Pakistan: orange, pink, red).
- Choose a different hue family, then check it on the phone home screen next to common apps.
- A loud primary is fine if a calm ink and neutral scale do most of the work (80% neutrals, 15% ink, 5% loud color).
