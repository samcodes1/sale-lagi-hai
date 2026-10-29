import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

/// Formats numbers, prices and dates for display.
///
/// Prices use Western digit grouping (`Rs 12,500`), as Pakistani retailers
/// do. Urdu text keeps Western digits by default too (the `ur` locale in
/// intl does); [urduDigits] is the opt-in setting that renders ۰–۹ instead.
@immutable
final class AppFormatters {
  const new(this._l10n, this.locale, {this.urduDigits = false});

  /// The formatters for the current context's locale.
  factory of(BuildContext context, {bool urduDigits = false}) => AppFormatters(
    AppLocalizations.of(context),
    Localizations.localeOf(context),
    urduDigits: urduDigits,
  );

  final AppLocalizations _l10n;
  final Locale locale;
  final bool urduDigits;

  static final _grouped = NumberFormat.decimalPattern('en');

  /// `12500` → `12,500` (or `۱۲,۵۰۰`).
  String number(num value) => _digits(_grouped.format(value));

  /// `2999` → `Rs 2,999` / `2,999 روپے`.
  String price(int rupees) => _l10n.priceRupees(number(rupees));

  /// Screen-reader text for a struck-through old price and a new price.
  String priceChange({required int was, required int now}) =>
      _l10n.priceWasNow(price(was), price(now));

  /// `-40%` badge text.
  String discount(int percent) => _l10n.discountBadge(percent);

  /// How far an outlet is: `350 m`, `1.2 km`, `14 km`. Metres are
  /// rounded to 50, kilometres to one decimal below 10 km.
  String distance(int meters) {
    // From 975 m the rounding reaches 1,000 m: say "1 km" instead.
    if (meters < 975) {
      final rounded = (meters / 50).round() * 50;
      return _l10n.distanceMeters(number(rounded < 50 ? 50 : rounded));
    }
    final km = meters / 1000;
    return _l10n.distanceKm(
      _digits(
        km < 10
            ? NumberFormat('0.#', 'en').format(km)
            : _grouped.format(km.round()),
      ),
    );
  }

  /// A short date such as `3 Nov` / `3 نومبر`.
  String shortDate(DateTime date) =>
      _digits(DateFormat('d MMM', locale.toLanguageTag()).format(date));

  String _digits(String text) => urduDigits ? toUrduDigits(text) : text;
}

/// Replaces ASCII digits with Urdu (Extended Arabic-Indic) digits ۰–۹.
String toUrduDigits(String text) => text.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => String.fromCharCode(0x06F0 + m[0]!.codeUnitAt(0) - 0x30),
);
