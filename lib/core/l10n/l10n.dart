import 'package:flutter/widgets.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

export 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

/// `context.l10n.navHome` instead of `AppLocalizations.of(context).navHome`.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
