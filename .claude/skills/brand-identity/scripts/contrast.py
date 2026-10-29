#!/usr/bin/env python3
"""WCAG 2.x contrast checker.
Usage:
  contrast.py FG BG                 -> ratio and pass/fail for text, large text, UI
  contrast.py --pairs pairs.json    -> [[fg, bg, "text"|"large"|"ui", "note"], ...]; exit 1 on any failure
Formula: https://www.w3.org/TR/WCAG22/#dfn-relative-luminance (sRGB, 0.04045 threshold)."""
import json, sys

NEED = {'text': 4.5, 'large': 3.0, 'ui': 3.0}

def lum(hex_):
    h = hex_.lstrip('#')
    if len(h) == 3: h = ''.join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def ratio(a, b):
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)

def main(argv):
    if len(argv) == 3 and argv[1] == '--pairs':
        fails = 0
        for fg, bg, kind, *note in json.load(open(argv[2])):
            r = ratio(fg, bg); ok = r >= NEED[kind]; fails += not ok   # never round before comparing
            print(f'{"PASS" if ok else "FAIL"}  {r:5.2f}:1  {fg} on {bg}  ({kind} >= {NEED[kind]})  {note[0] if note else ""}')
        return 1 if fails else 0
    if len(argv) == 3:
        r = ratio(argv[1], argv[2])
        print(f'{r:.2f}:1  text {"PASS" if r >= 4.5 else "FAIL"}  large {"PASS" if r >= 3 else "FAIL"}  ui {"PASS" if r >= 3 else "FAIL"}')
        return 0
    print(__doc__); return 2

if __name__ == '__main__':
    sys.exit(main(sys.argv))
