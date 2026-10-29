import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled brand fonts and their licence files. All are SIL Open Font
/// License 1.1, which requires the licence to ship with the fonts.
const fontLicenses = <(String, String)>[
  ('Bricolage Grotesque', 'assets/fonts/licenses/OFL-BricolageGrotesque.txt'),
  ('Instrument Sans', 'assets/fonts/licenses/OFL-InstrumentSans.txt'),
  ('Noto Nastaliq Urdu', 'assets/fonts/licenses/OFL-NotoNastaliqUrdu.txt'),
  ('Noto Naskh Arabic', 'assets/fonts/licenses/OFL-NotoNaskhArabic.txt'),
];

/// Adds the font licences to the app's licence page
/// (`showLicensePage`), which Settings → About links to.
void registerFontLicenses({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final assets = bundle ?? rootBundle;
    for (final (font, path) in fontLicenses) {
      yield LicenseEntryWithLineBreaks([font], await assets.loadString(path));
    }
  });
}
