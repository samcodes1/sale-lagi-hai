"""Single source for design tokens.
Writes: tokens/brand_tokens.json, flutter/brand_tokens.dart, tokens/contrast-report.md
and fails (exit 1) if any required WCAG 2.2 contrast pair is below threshold.
Run: python3 design/_src/build_tokens.py"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..')

# ---------------------------------------------------------------- palette
PALETTE = {
    # Haldi: turmeric yellow. The brand. A surface colour, never a text colour on light.
    'haldi': {'50': '#FFF8E1', '100': '#FFEDB3', '200': '#FFE07A', '300': '#FFD447', '400': '#FFCB2B',
              '500': '#FFC414', '600': '#E6A800', '700': '#B78100', '800': '#8A5F00', '900': '#5C3F00'},
    # Surma: kohl ink. Text, the mark, dark theme surfaces. Warm-violet neutrals.
    'surma': {'0': '#FFFFFF', '50': '#FAF8F4', '100': '#F2EFEA', '200': '#E3DFD9', '300': '#CBC6C0',
              '400': '#A29DA6', '500': '#7B7585', '600': '#5D5769', '700': '#433D50', '800': '#2C263A',
              '900': '#1A1433', '950': '#0F0B1F'},
    # Neel: truck-art blue. Links, selection, focus, info.
    'neel': {'50': '#EEEFFF', '100': '#DCDDFF', '200': '#BCBEFF', '300': '#9EA2FF', '400': '#7378F2',
             '500': '#3B3FD9', '600': '#2F32B8', '700': '#262894', '800': '#1D1F70', '900': '#15164D'},
    # Mirch: chilli red. Deal / hot badges ONLY (discount %, "ends tonight").
    'mirch': {'50': '#FFF0EE', '100': '#FFDAD5', '200': '#FFB4AB', '300': '#FF8A7E', '400': '#FF6B5E',
              '500': '#DC2E24', '600': '#B8221A', '700': '#921A14', '800': '#6E130F', '900': '#4A0C09'},
    # Semantic
    'success': {'50': '#E6F6EC', '300': '#5FD39A', '500': '#18794E', '800': '#0E3B27'},
    'warning': {'50': '#FFF1DC', '300': '#FFB547', '500': '#A34D00', '800': '#4A2600'},
    'error':   {'50': '#FEE4E2', '300': '#FF8F87', '500': '#B42318', '800': '#55120C'},
    'info':    {'50': '#EEEFFF', '300': '#9EA2FF', '500': '#3B3FD9', '800': '#1D1F70'},
    'kaghaz': {'500': '#FFF8E7'},  # paper, used behind the logo
}
P = lambda s: PALETTE[s.split('.')[0]][s.split('.')[1]]

THEMES = {
    'light': {
        'background': 'surma.50', 'surface': 'surma.0', 'surfaceVariant': 'surma.100',
        'surfaceInverse': 'surma.900', 'onSurfaceInverse': 'kaghaz.500',
        'textPrimary': 'surma.900', 'textSecondary': 'surma.600', 'textDisabled': 'surma.400',
        'outline': 'surma.200', 'outlineStrong': 'surma.500',
        'primary': 'haldi.500', 'onPrimary': 'surma.900', 'primaryContainer': 'haldi.100', 'onPrimaryContainer': 'haldi.900',
        'primaryText': 'haldi.800',
        'secondary': 'neel.500', 'onSecondary': 'surma.0', 'secondaryContainer': 'neel.50', 'onSecondaryContainer': 'neel.800',
        'deal': 'mirch.500', 'onDeal': 'surma.0', 'dealContainer': 'mirch.50', 'onDealContainer': 'mirch.700',
        'featured': 'haldi.500', 'onFeatured': 'surma.900',
        'success': 'success.500', 'successContainer': 'success.50',
        'warning': 'warning.500', 'warningContainer': 'warning.50',
        'error': 'error.500', 'onError': 'surma.0', 'errorContainer': 'error.50',
        'info': 'info.500', 'infoContainer': 'info.50',
        'focus': 'neel.500',
        'indicator': 'surma.900',  # selected tab/switch/progress: Haldi is too light on paper
    },
    'dark': {
        'background': 'surma.950', 'surface': 'surma.900', 'surfaceVariant': 'surma.800',
        'surfaceInverse': 'surma.50', 'onSurfaceInverse': 'surma.900',
        'textPrimary': 'surma.50', 'textSecondary': 'surma.400', 'textDisabled': 'surma.600',
        'outline': 'surma.700', 'outlineStrong': 'surma.500',
        'primary': 'haldi.500', 'onPrimary': 'surma.900', 'primaryContainer': 'haldi.900', 'onPrimaryContainer': 'haldi.100',
        'primaryText': 'haldi.500',
        'secondary': 'neel.300', 'onSecondary': 'neel.900', 'secondaryContainer': 'neel.800', 'onSecondaryContainer': 'neel.100',
        'deal': 'mirch.400', 'onDeal': 'surma.950', 'dealContainer': 'mirch.900', 'onDealContainer': 'mirch.200',
        'featured': 'haldi.500', 'onFeatured': 'surma.900',
        'success': 'success.300', 'successContainer': 'success.800',
        'warning': 'warning.300', 'warningContainer': 'warning.800',
        'error': 'error.300', 'onError': 'surma.950', 'errorContainer': 'error.800',
        'info': 'info.300', 'infoContainer': 'info.800',
        'focus': 'neel.300',
        'indicator': 'haldi.500',
    },
}

# (foreground, background, kind, note). kind: text = 4.5, large = 3.0 (>=24px or >=18.66px bold), ui = 3.0 (1.4.11)
CHECKS = [
    ('textPrimary', 'background', 'text', 'body text'),
    ('textPrimary', 'surface', 'text', 'body text on cards'),
    ('textPrimary', 'surfaceVariant', 'text', 'text on chips/inputs'),
    ('textSecondary', 'background', 'text', 'secondary text'),
    ('textSecondary', 'surface', 'text', 'secondary text on cards'),
    ('onPrimary', 'primary', 'text', 'label on Haldi button'),
    ('onPrimaryContainer', 'primaryContainer', 'text', 'tonal button'),
    ('primaryText', 'surface', 'text', 'brand-coloured text'),
    ('onSecondary', 'secondary', 'text', 'label on Neel button'),
    ('secondary', 'surface', 'text', 'links'),
    ('secondary', 'background', 'text', 'links on background'),
    ('onSecondaryContainer', 'secondaryContainer', 'text', 'selected chip'),
    ('onDeal', 'deal', 'text', 'discount badge "-40%"'),
    ('onDealContainer', 'dealContainer', 'text', 'soft deal label'),
    ('deal', 'surface', 'ui', 'badge shape vs card'),
    ('onFeatured', 'featured', 'text', 'Featured/sponsored badge'),
    ('success', 'surface', 'text', 'success text'),
    ('success', 'successContainer', 'text', 'success banner'),
    ('warning', 'surface', 'text', 'warning text'),
    ('warning', 'warningContainer', 'text', 'warning banner'),
    ('error', 'surface', 'text', 'error text'),
    ('error', 'errorContainer', 'text', 'error banner'),
    ('onError', 'error', 'text', 'destructive button'),
    ('info', 'surface', 'text', 'info text'),
    ('info', 'infoContainer', 'text', 'info banner'),
    ('outlineStrong', 'surface', 'ui', 'input border / checkbox'),
    ('focus', 'background', 'ui', 'focus ring'),
    ('onSurfaceInverse', 'surfaceInverse', 'text', 'snackbar'),
    ('indicator', 'background', 'ui', 'selected tab / switch / progress indicator'),
    ('indicator', 'surface', 'ui', 'indicator on cards'),
]
EXTRA = [  # brand pairs outside the themes
    ('surma.900', 'haldi.500', 'ui', 'logo: ink bang on Haldi (app icon)'),
    ('haldi.500', 'surma.900', 'ui', 'logo: Haldi bang on ink'),
    ('surma.900', 'kaghaz.500', 'text', 'wordmark on paper'),
    ('surma.0', 'mirch.500', 'text', 'white on Mirch badge (both themes allowed)'),
]

def lum(h):
    h = h.lstrip('#'); r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)

NEED = {'text': 4.5, 'large': 3.0, 'ui': 3.0}

def contrast_report():
    rows, fails = [], 0
    for th, roles in THEMES.items():
        for fg, bg, kind, note in CHECKS:
            a, b = P(roles[fg]), P(roles[bg]); r = ratio(a, b); ok = r >= NEED[kind]
            fails += not ok
            rows.append((th, f'{fg} on {bg}', a, b, r, kind, ok, note))
    for fg, bg, kind, note in EXTRA:
        a, b = P(fg), P(bg); r = ratio(a, b); ok = r >= NEED[kind]; fails += not ok
        rows.append(('brand', f'{fg} on {bg}', a, b, r, kind, ok, note))
    return rows, fails

# ---------------------------------------------------------------- type, space, etc.
FONTS = {
    'display': {'family': 'BricolageCondensed', 'file': 'BricolageGrotesqueCondensed-ExtraBold.ttf', 'weight': 800,
                'note': 'Bricolage Grotesque, wght 800 wdth 75 opsz 96 (static instance)'},
    'title': {'family': 'BricolageGrotesque', 'file': 'BricolageGrotesque-Bold.ttf', 'weight': 700,
              'note': 'Bricolage Grotesque, wght 700 wdth 100 opsz 24'},
    'ui': {'family': 'InstrumentSans', 'files': {'400': 'InstrumentSans-Regular.ttf', '500': 'InstrumentSans-Medium.ttf',
                                                  '600': 'InstrumentSans-SemiBold.ttf', '700': 'InstrumentSans-Bold.ttf'}},
    'urdu': {'family': 'NotoNastaliqUrdu', 'files': {'400': 'NotoNastaliqUrdu-Regular.ttf', '700': 'NotoNastaliqUrdu-Bold.ttf'}},
    'urduCompact': {'family': 'NotoNaskhArabic', 'files': {'400': 'NotoNaskhArabic-Regular.ttf', '700': 'NotoNaskhArabic-Bold.ttf'},
                    'note': 'Optional compact Urdu (Naskh) for tight numeric UI.'},
}
# name: (font role, size, line-height multiplier, weight, letterSpacing px, features)
TYPE = {
    'displayLarge': ('display', 44, 1.04, 800, -0.4, []),
    'displayMedium': ('display', 36, 1.06, 800, -0.3, []),
    'headline': ('display', 28, 1.1, 800, -0.2, []),
    'price': ('display', 28, 1.0, 800, 0.0, ['tnum']),
    'badge': ('display', 15, 1.0, 800, 0.3, ['tnum']),
    'titleLarge': ('title', 22, 1.25, 700, -0.1, []),
    'titleMedium': ('ui', 17, 1.35, 600, 0.0, []),
    'bodyLarge': ('ui', 16, 1.5, 400, 0.0, []),
    'bodyMedium': ('ui', 14, 1.45, 400, 0.05, []),
    'bodySmall': ('ui', 12, 1.4, 400, 0.1, []),
    'labelLarge': ('ui', 15, 1.2, 600, 0.1, []),
    'labelSmall': ('ui', 12, 1.2, 600, 0.3, []),
    'numeric': ('ui', 14, 1.3, 500, 0.0, ['tnum']),
    # Urdu: Nastaliq is optically smaller and needs ~2x leading. Sizes are +2..4px over the Latin twin.
    'urduDisplay': ('urdu', 34, 2.0, 700, 0.0, []),
    'urduHeadline': ('urdu', 26, 2.0, 700, 0.0, []),
    'urduTitle': ('urdu', 20, 2.0, 700, 0.0, []),
    'urduBody': ('urdu', 18, 2.1, 400, 0.0, []),
    'urduBodySmall': ('urdu', 15, 2.1, 400, 0.0, []),
    'urduLabel': ('urdu', 16, 1.9, 700, 0.0, []),
}
RADII = {'none': 0, 'xs': 4, 'sm': 8, 'md': 12, 'lg': 16, 'xl': 24, 'full': 999}
SPACING = {'0': 0, '1': 2, '2': 4, '3': 8, '4': 12, '5': 16, '6': 20, '7': 24, '8': 32, '9': 40, '10': 48, '11': 64}
# Shadows are tinted with Surma ink, never pure black. Dark theme uses surface steps, not shadows.
ELEVATION = {
    '0': [],
    '1': [{'x': 0, 'y': 1, 'blur': 2, 'spread': 0, 'color': '#1A1433', 'opacity': 0.08}],
    '2': [{'x': 0, 'y': 2, 'blur': 6, 'spread': -1, 'color': '#1A1433', 'opacity': 0.10},
          {'x': 0, 'y': 1, 'blur': 2, 'spread': 0, 'color': '#1A1433', 'opacity': 0.06}],
    '3': [{'x': 0, 'y': 8, 'blur': 20, 'spread': -4, 'color': '#1A1433', 'opacity': 0.16},
          {'x': 0, 'y': 2, 'blur': 4, 'spread': 0, 'color': '#1A1433', 'opacity': 0.06}],
    'stamp': [{'x': 3, 'y': 3, 'blur': 0, 'spread': 0, 'color': '#1A1433', 'opacity': 1.0}],
}
MOTION = {
    'duration': {'instant': 80, 'fast': 140, 'base': 220, 'slow': 320, 'stamp': 180, 'splash': 700},
    'easing': {'standard': [0.2, 0.0, 0.0, 1.0], 'enter': [0.0, 0.0, 0.0, 1.0], 'exit': [0.3, 0.0, 1.0, 1.0],
               'stamp': [0.34, 1.4, 0.64, 1.0]},
    'notes': 'stamp = the nuqta landing: quick overshoot, used once per screen at most (new-deal badge, alert bell).',
}

def build_json():
    return {
        '$schema': 'sale-lagi-hai brand tokens v1',
        'meta': {'brand': 'Sale Lagi Hai!', 'version': '1.0.0', 'generatedBy': 'design/_src/build_tokens.py'},
        'color': {'palette': PALETTE, 'themes': {t: {k: {'ref': v, 'value': P(v)} for k, v in r.items()} for t, r in THEMES.items()}},
        'font': FONTS,
        'typography': {k: {'font': v[0], 'family': FONTS[v[0]]['family'], 'size': v[1], 'lineHeight': v[2],
                           'weight': v[3], 'letterSpacing': v[4], 'features': v[5]} for k, v in TYPE.items()},
        'radius': RADII, 'spacing': SPACING, 'elevation': ELEVATION, 'motion': MOTION,
    }

# ---------------------------------------------------------------- dart
def cname(s):  # haldi.500 -> haldi500
    a, b = s.split('.'); return a + b

def dcolor(h, op=1.0):
    a = round(op * 255)
    return f'Color(0x{a:02X}{h.lstrip("#").upper()})'

def dnum(v):
    v = float(v)
    return str(int(v)) if v.is_integer() else repr(v)

ROLE_DOCS = {
    'background': 'Screen background.', 'surface': 'Cards, sheets, app bars.',
    'surfaceVariant': 'Chips, inputs, subtle fills.', 'surfaceInverse': 'Snackbars and tooltips.',
    'onSurfaceInverse': 'Text on [surfaceInverse].', 'textPrimary': 'Primary text and icons.',
    'textSecondary': 'Secondary text, captions.', 'textDisabled': 'Disabled text (exempt from contrast).',
    'outline': 'Dividers and decorative borders.', 'outlineStrong': 'Input borders, checkboxes (3:1).',
    'primary': 'Haldi brand fill: primary buttons, the logo tile.', 'onPrimary': 'Text/icons on [primary].',
    'primaryContainer': 'Tonal brand fill.', 'onPrimaryContainer': 'Text on [primaryContainer].',
    'primaryText': 'Brand-family colour when it must be text.', 'secondary': 'Neel: links, secondary buttons.',
    'onSecondary': 'Text on [secondary].', 'secondaryContainer': 'Selected chip fill.',
    'onSecondaryContainer': 'Text on [secondaryContainer].', 'deal': 'Mirch: discount badges only.',
    'onDeal': 'Text on [deal].', 'dealContainer': 'Soft deal label fill.', 'onDealContainer': 'Text on [dealContainer].',
    'featured': 'Featured/sponsored badge fill.', 'onFeatured': 'Text on [featured].',
    'success': 'Success text/icons.', 'successContainer': 'Success banner fill.',
    'warning': 'Warning text/icons.', 'warningContainer': 'Warning banner fill.',
    'error': 'Error text/icons.', 'onError': 'Text on [error].', 'errorContainer': 'Error banner fill.',
    'info': 'Info text/icons.', 'infoContainer': 'Info banner fill.', 'focus': 'Focus ring.',
    'indicator': 'Selected tab, switch, progress indicator.',
}
TYPE_DOCS = {
    'displayLarge': 'Hero numbers and splash headlines.', 'displayMedium': 'Screen hero titles.',
    'headline': 'Section headlines, deal titles on detail pages.', 'price': 'Deal price, tabular figures.',
    'badge': 'Discount badge text such as -40%.', 'titleLarge': 'Card titles, app bar titles.',
    'titleMedium': 'List item titles.', 'bodyLarge': 'Long-form body text.', 'bodyMedium': 'Default body text.',
    'bodySmall': 'Captions and meta (distance, expiry).', 'labelLarge': 'Buttons.', 'labelSmall': 'Chips, tags.',
    'numeric': 'Inline numbers that must align (tabular).', 'urduDisplay': 'Urdu hero titles.',
    'urduHeadline': 'Urdu section headlines.', 'urduTitle': 'Urdu card titles.', 'urduBody': 'Urdu body text.',
    'urduBodySmall': 'Urdu captions.', 'urduLabel': 'Urdu buttons and chips.',
}

def build_dart():
    L = []
    w = L.append
    w('// GENERATED by design/_src/build_tokens.py. Edit the generator, not this file.')
    w('// Sale Lagi Hai! brand tokens. Drop into lib/design_system/.')
    w('// Fonts: copy design/fonts/static/*.ttf to assets/fonts/ and declare them')
    w('// in pubspec.yaml (see the snippet at the end of this file).')
    w('')
    w("import 'package:flutter/material.dart';")
    w('')
    w('/// Raw palette. Prefer the role colours in [BrandLight] / [BrandDark].')
    w('abstract final class BrandColors {')
    for fam, steps in PALETTE.items():
        for k, v in steps.items():
            w(f'  /// {fam.capitalize()} {k}: {v}.')
            w(f'  static const Color {fam}{k} = {dcolor(v)};')
        w('')
    if L[-1] == '': L.pop()
    w('}')
    w('')
    for th, roles in THEMES.items():
        cls = 'BrandLight' if th == 'light' else 'BrandDark'
        w(f'/// {th.capitalize()} theme colour roles.')
        w(f'abstract final class {cls} {{')
        for k, v in roles.items():
            w(f'  /// {ROLE_DOCS[k]} {P(v)}.')
            w(f'  static const Color {k} = BrandColors.{cname(v)};')
        w('}')
        w('')
    def scheme(th):
        r = THEMES[th]; c = lambda k: f'BrandColors.{cname(r[k])}'
        b = 'Brightness.light' if th == 'light' else 'Brightness.dark'
        return f"""  /// {th.capitalize()} scheme.
  static const ColorScheme {th} = ColorScheme(
    brightness: {b},
    primary: {c('primary')},
    onPrimary: {c('onPrimary')},
    primaryContainer: {c('primaryContainer')},
    onPrimaryContainer: {c('onPrimaryContainer')},
    secondary: {c('secondary')},
    onSecondary: {c('onSecondary')},
    secondaryContainer: {c('secondaryContainer')},
    onSecondaryContainer: {c('onSecondaryContainer')},
    tertiary: {c('deal')},
    onTertiary: {c('onDeal')},
    tertiaryContainer: {c('dealContainer')},
    onTertiaryContainer: {c('onDealContainer')},
    error: {c('error')},
    onError: {c('onError')},
    errorContainer: {c('errorContainer')},
    onErrorContainer: {c('textPrimary')},
    surface: {c('surface')},
    onSurface: {c('textPrimary')},
    onSurfaceVariant: {c('textSecondary')},
    outline: {c('outlineStrong')},
    outlineVariant: {c('outline')},
    shadow: BrandColors.surma900,
    scrim: BrandColors.surma950,
    inverseSurface: {c('surfaceInverse')},
    onInverseSurface: {c('onSurfaceInverse')},
    inversePrimary: BrandColors.haldi800,
    surfaceTint: Colors.transparent,
  );"""
    w('/// Material 3 colour schemes. tertiary = the Mirch deal accent.')
    w('abstract final class BrandColorSchemes {')
    w(scheme('light'))
    w('')
    w(scheme('dark'))
    w('}')
    w('')
    w('/// Font families as declared in pubspec.yaml.')
    w('abstract final class BrandFonts {')
    for k, v in FONTS.items():
        w(f"  /// {v.get('note', v['family'])}")
        w(f"  static const String {k} = '{v['family']}';")
    w('')
    w('  /// Fallback for Latin styles that meet Urdu text.')
    w("  static const List<String> latinFallback = <String>['NotoNastaliqUrdu'];")
    w('')
    w('  /// Fallback for Urdu styles that meet Latin (brand names, prices).')
    w("  static const List<String> urduFallback = <String>['InstrumentSans'];")
    w('}')
    w('')
    w('/// Type scale. Urdu styles carry their own tall line height:')
    w('/// never reuse a Latin style for Urdu text.')
    w('abstract final class BrandTypography {')
    for k, (role, size, lh, wt, ls, feats) in TYPE.items():
        fb = 'BrandFonts.urduFallback' if role.startswith('urdu') else 'BrandFonts.latinFallback'
        lines = [f'    fontFamily: BrandFonts.{role},', f'    fontFamilyFallback: {fb},',
                 f'    fontSize: {dnum(size)},', f'    height: {dnum(lh)},', f'    fontWeight: FontWeight.w{wt},']
        if ls: lines.append(f'    letterSpacing: {dnum(ls)},')
        if feats:
            lines.append('    fontFeatures: <FontFeature>[' + ', '.join(f"FontFeature.enable('{x}')" for x in feats) + '],')
        if role.startswith('urdu'):
            lines.append('    leadingDistribution: TextLeadingDistribution.even,')
        w(f'  /// {TYPE_DOCS[k]} {size}/{lh}.')
        w(f'  static const TextStyle {k} = TextStyle(')
        L.extend(lines)
        w('  );')
        w('')
    w('  /// Material TextTheme mapping (Latin). For Urdu use [urduTextTheme].')
    w('  static const TextTheme textTheme = TextTheme(')
    for m, k in [('displayLarge', 'displayLarge'), ('displayMedium', 'displayMedium'), ('displaySmall', 'headline'),
                 ('headlineLarge', 'displayMedium'), ('headlineMedium', 'headline'), ('headlineSmall', 'titleLarge'),
                 ('titleLarge', 'titleLarge'), ('titleMedium', 'titleMedium'), ('titleSmall', 'labelLarge'),
                 ('bodyLarge', 'bodyLarge'), ('bodyMedium', 'bodyMedium'), ('bodySmall', 'bodySmall'),
                 ('labelLarge', 'labelLarge'), ('labelMedium', 'labelSmall'), ('labelSmall', 'labelSmall')]:
        w(f'    {m}: {k},')
    w('  );')
    w('')
    w('  /// Material TextTheme mapping for the Urdu locale.')
    w('  static const TextTheme urduTextTheme = TextTheme(')
    for m, k in [('displayLarge', 'urduDisplay'), ('displayMedium', 'urduDisplay'), ('displaySmall', 'urduHeadline'),
                 ('headlineLarge', 'urduHeadline'), ('headlineMedium', 'urduHeadline'), ('headlineSmall', 'urduTitle'),
                 ('titleLarge', 'urduTitle'), ('titleMedium', 'urduLabel'), ('titleSmall', 'urduLabel'),
                 ('bodyLarge', 'urduBody'), ('bodyMedium', 'urduBody'), ('bodySmall', 'urduBodySmall'),
                 ('labelLarge', 'urduLabel'), ('labelMedium', 'urduBodySmall'), ('labelSmall', 'urduBodySmall')]:
        w(f'    {m}: {k},')
    w('  );')
    w('}')
    w('')
    w('/// Corner radii in dp.')
    w('abstract final class BrandRadii {')
    for k, v in RADII.items():
        w(f'  /// Radius {k}: {v} dp.')
        w(f'  static const double {k} = {dnum(v)};')
        w('')
    w('  /// Cards and tiles.')
    w('  static const BorderRadius card = BorderRadius.all(Radius.circular(md));')
    w('')
    w('  /// Buttons and inputs.')
    w('  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));')
    w('')
    w('  /// Deal badges (nearly square: they are stamps, not pills).')
    w('  static const BorderRadius badge = BorderRadius.all(Radius.circular(xs));')
    w('')
    w('  /// Bottom sheets.')
    w('  static const BorderRadius sheet = BorderRadius.vertical(')
    w('    top: Radius.circular(xl),')
    w('  );')
    w('}')
    w('')
    w('/// 4-pt spacing scale in dp.')
    w('abstract final class BrandSpacing {')
    for k, v in SPACING.items():
        w(f'  /// Step {k}: {v} dp.')
        w(f'  static const double s{k} = {dnum(v)};')
        w('')
    w('  /// Horizontal screen gutter.')
    w('  static const double screenGutter = 16;')
    w('')
    w('  /// Minimum touch target.')
    w('  static const double minTouchTarget = 48;')
    w('}')
    w('')
    w('/// Shadows tinted with Surma ink. In dark theme prefer surface steps.')
    w('abstract final class BrandElevation {')
    for k, sh in ELEVATION.items():
        name = f'e{k}' if k[0].isdigit() else k
        doc = 'Hard offset "sign-painter" shadow for the logo tile and badges.' if k == 'stamp' else f'Elevation level {k}.'
        w(f'  /// {doc}')
        if not sh:
            w(f'  static const List<BoxShadow> {name} = <BoxShadow>[];')
            w('')
            continue
        w(f'  static const List<BoxShadow> {name} = <BoxShadow>[')
        for s_ in sh:
            args = [f'color: {dcolor(s_["color"], s_["opacity"])}', f'offset: Offset({dnum(s_["x"])}, {dnum(s_["y"])})']
            if s_['blur']: args.append(f'blurRadius: {dnum(s_["blur"])}')
            if s_['spread']: args.append(f'spreadRadius: {dnum(s_["spread"])}')
            w('    BoxShadow(')
            for a_ in args: w(f'      {a_},')
            w('    ),')
        w('  ];')
        w('')
    if L[-1] == '': L.pop()
    w('}')
    w('')
    w('/// Motion durations and curves.')
    w('abstract final class BrandMotion {')
    for k, v in MOTION['duration'].items():
        w(f'  /// {k}: {v} ms.')
        w(f'  static const Duration {k} = Duration(milliseconds: {v});')
        w('')
    for k, v in MOTION['easing'].items():
        doc = 'Nuqta "stamp" with a small overshoot. Once per screen at most.' if k == 'stamp' else f'{k} easing.'
        w(f'  /// {doc}')
        w(f'  static const Curve {k}Curve = Cubic({", ".join(dnum(x) for x in v)});')
        w('')
    if L[-1] == '': L.pop()
    w('}')
    w('')
    w('/// Convenience ThemeData builders. They only wire tokens.')
    w('abstract final class BrandTheme {')
    for th in ('light', 'dark'):
        cls = 'BrandLight' if th == 'light' else 'BrandDark'
        w(f'  /// {th.capitalize()} theme. Pass `urdu: true` for the Urdu locale.')
        w(f'  static ThemeData {th}({{bool urdu = false}}) {{')
        w(f'    final base = urdu')
        w('        ? BrandTypography.urduTextTheme')
        w('        : BrandTypography.textTheme;')
        w('    return ThemeData(')
        w(f'      colorScheme: BrandColorSchemes.{th},')
        w(f'      scaffoldBackgroundColor: {cls}.background,')
        w('      fontFamily: urdu ? BrandFonts.urdu : BrandFonts.ui,')
        w('      textTheme: base.apply(')
        w(f'        bodyColor: {cls}.textPrimary,')
        w(f'        displayColor: {cls}.textPrimary,')
        w('      ),')
        w(f'      dividerColor: {cls}.outline,')
        w('    );')
        w('  }')
        if th == 'light': w('')
    w('}')
    w('')
    w('// pubspec.yaml snippet:')
    w('//')
    w('// flutter:')
    w('//   fonts:')
    w('//     - family: BricolageCondensed')
    w('//       fonts:')
    w('//         - asset: assets/fonts/BricolageGrotesqueCondensed-ExtraBold.ttf')
    w('//           weight: 800')
    w('//     - family: BricolageGrotesque')
    w('//       fonts:')
    w('//         - asset: assets/fonts/BricolageGrotesque-Bold.ttf')
    w('//           weight: 700')
    w('//     - family: InstrumentSans')
    w('//       fonts:')
    for wt, fn in FONTS['ui']['files'].items():
        w(f'//         - asset: assets/fonts/{fn}')
        w(f'//           weight: {wt}')
    w('//     - family: NotoNastaliqUrdu')
    w('//       fonts:')
    for wt, fn in FONTS['urdu']['files'].items():
        w(f'//         - asset: assets/fonts/{fn}')
        w(f'//           weight: {wt}')
    w('//     # Optional compact Urdu (Naskh), see BRAND_GUIDELINES.md:')
    w('//     - family: NotoNaskhArabic')
    w('//       fonts:')
    w('//         - asset: assets/fonts/NotoNaskhArabic-Regular.ttf')
    w('//         - asset: assets/fonts/NotoNaskhArabic-Bold.ttf')
    w('//           weight: 700')
    return '\n'.join(L) + '\n'

def main():
    rows, fails = contrast_report()
    os.makedirs(os.path.join(D, 'tokens'), exist_ok=True); os.makedirs(os.path.join(D, 'flutter'), exist_ok=True)
    json.dump(build_json(), open(os.path.join(D, 'tokens', 'brand_tokens.json'), 'w'), indent=2)
    dart_path = os.path.join(D, 'flutter', 'brand_tokens.dart')
    open(dart_path, 'w').write(build_dart())
    import shutil, subprocess
    dart = shutil.which('dart') or '/opt/flutter/bin/dart'
    if os.path.exists(dart):
        subprocess.run([dart, 'format', dart_path], check=False, capture_output=True)
    md = ['# Contrast report (WCAG 2.2)', '',
          'Generated by `design/_src/build_tokens.py`. Relative luminance and ratio per WCAG 2.x definition',
          '(sRGB, 0.04045 threshold). Thresholds: text 4.5:1 (SC 1.4.3), large text and UI/graphics 3:1 (SC 1.4.3, 1.4.11).',
          'Ratios are not rounded before comparison.', '',
          '| Theme | Pair | FG | BG | Ratio | Needs | Result | Used for |', '|---|---|---|---|---|---|---|---|']
    for th, pair, a, b, r, kind, ok, note in rows:
        md.append(f'| {th} | {pair} | `{a}` | `{b}` | {r:.2f}:1 | {NEED[kind]}:1 ({kind}) | {"PASS" if ok else "**FAIL**"} | {note} |')
    md += ['', f'**{len(rows) - fails}/{len(rows)} pairs pass.**', '',
           'Known non-text exceptions (decorative, allowed by WCAG but noted): Haldi `#FFC414` on white is 1.60:1, so Haldi is',
           'never used for text, thin icons, borders or state indicators on light surfaces. A Haldi button is fine because',
           'its ink label (11.04:1) identifies it (WCAG 1.4.11 "Boundaries"); selected states use the `indicator` role. Use `primaryText` (Haldi 800) when a yellow-family text colour is needed.']
    open(os.path.join(D, 'tokens', 'contrast-report.md'), 'w').write('\n'.join(md) + '\n')
    for th, pair, a, b, r, kind, ok, note in rows:
        if not ok: print('FAIL', th, pair, a, b, round(r, 2), kind)
    print(f'{len(rows) - fails}/{len(rows)} pass')
    return 1 if fails else 0

if __name__ == '__main__':
    sys.exit(main())
