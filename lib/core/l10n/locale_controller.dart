import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

/// The languages the app ships: English (default) and Urdu.
abstract final class AppLocales {
  static const english = Locale('en');
  static const urdu = Locale('ur');
  static const List<Locale> supported = AppLocalizations.supportedLocales;

  /// Maps any locale to a supported one by language: `ur_PK` → `ur`,
  /// anything that is not Urdu → English.
  static Locale resolve(Locale? locale) =>
      locale?.languageCode == urdu.languageCode ? urdu : english;

  static bool isRtl(Locale locale) => locale.languageCode == 'ur';
}

/// Storage key for the chosen language.
const localeStorageKey = 'settings.locale';

/// The phone's language. Overridable in tests.
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// The language saved by an earlier session, read once in `bootstrap`
/// before the first frame so the app never flashes the wrong language.
/// `null` means the user never chose one.
final savedLocaleProvider = Provider<Locale?>((ref) => null);

/// The app's current language.
///
/// Starts from the saved choice, else the phone's language (Urdu phones get
/// Urdu, everything else English). [LocaleController.select] changes and
/// saves it.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

final class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => AppLocales.resolve(
    ref.watch(savedLocaleProvider) ?? ref.watch(deviceLocaleProvider),
  );

  /// Switches to [locale] (resolved to a supported one) and saves it. A
  /// failed save is logged; the switch still applies for this session.
  Future<void> select(Locale locale) async {
    final resolved = AppLocales.resolve(locale);
    state = resolved;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(localeStorageKey, resolved.languageCode);
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not save the language choice', error: error);
    }
  }
}
