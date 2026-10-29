// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sale Lagi Hai!';

  @override
  String get appTagline => 'First to know when the sale is on.';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navSaved => 'Saved';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSave => 'Save';

  @override
  String get actionUnsave => 'Remove from saved';

  @override
  String get actionShare => 'Share';

  @override
  String get actionShareWhatsApp => 'Share on WhatsApp';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionClearFilters => 'Clear filters';

  @override
  String get actionSetAlert => 'Set alert';

  @override
  String get actionTurnOnAlerts => 'Turn on alerts';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get actionFollow => 'Follow';

  @override
  String get actionFollowing => 'Following';

  @override
  String get actionReport => 'Report';

  @override
  String get actionViewTerms => 'View terms';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get actionPickArea => 'Pick your area';

  @override
  String get loadingDeals => 'Loading deals';

  @override
  String get offlineBanner =>
      'No internet. Your saved deals still work; new ones will load when you\'re back.';

  @override
  String updatedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count minutes ago',
      one: 'Updated 1 minute ago',
      zero: 'Updated just now',
    );
    return '$_temp0';
  }

  @override
  String updatedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count hours ago',
      one: 'Updated 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String updatedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count days ago',
      one: 'Updated yesterday',
    );
    return '$_temp0';
  }

  @override
  String verifiedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verified $count minutes ago',
      one: 'Verified 1 minute ago',
      zero: 'Verified just now',
    );
    return '$_temp0';
  }

  @override
  String verifiedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verified $count hours ago',
      one: 'Verified 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String verifiedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verified $count days ago',
      one: 'Verified yesterday',
    );
    return '$_temp0';
  }

  @override
  String endsInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ends in $count hours',
      one: 'Ends in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String endsInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ends in $count days',
      one: 'Ends tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get endsToday => 'Ends today';

  @override
  String endsOn(String date) {
    return 'Ends $date';
  }

  @override
  String get dealOngoing => 'Ongoing';

  @override
  String get dealExpired => 'Expired';

  @override
  String get featuredLabel => 'Featured';

  @override
  String discountBadge(int percent) {
    return '-$percent%';
  }

  @override
  String flatPercentOff(int percent) {
    return 'Flat $percent% off';
  }

  @override
  String upToPercentOff(int percent) {
    return 'Up to $percent% off';
  }

  @override
  String priceRupees(String amount) {
    return 'Rs $amount';
  }

  @override
  String priceWasNow(String oldPrice, String newPrice) {
    return 'was $oldPrice, now $newPrice';
  }

  @override
  String get allPakistan => 'All Pakistan';

  @override
  String get online => 'Online';

  @override
  String get emptyNearby =>
      'Quiet day in the bazaar. No sales near you right now; we\'ll shout when one starts.';

  @override
  String get emptySaved =>
      'Nothing saved yet. Tap the bookmark on a deal to keep it here.';

  @override
  String get emptyAlerts =>
      'Follow a brand and we\'ll tell you the moment its sale starts.';

  @override
  String emptySearch(String query) {
    return 'No deals for “⁨$query⁩”. Try another word or clear the filters.';
  }

  @override
  String get locationOff =>
      'Allow location to see deals near you, or pick your area.';

  @override
  String get errorOffline =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorTimeout =>
      'That took too long. Check your connection and try again.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Try again in a minute.';

  @override
  String get errorUnauthorized =>
      'Your session has ended. Please sign in again.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'We couldn\'t find this. It may have ended.';

  @override
  String get errorValidation =>
      'Some details need fixing. Check the highlighted fields.';

  @override
  String get errorRateLimited =>
      'Too many tries. Please wait a moment and try again.';

  @override
  String get errorStorage =>
      'Couldn\'t save on this phone. Free up some space and try again.';

  @override
  String get errorUnexpected => 'Something went wrong. Try again.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get dealTitle => 'Deal';

  @override
  String get brandTitle => 'Brand';

  @override
  String get categoryTitle => 'Category';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody =>
      'This link doesn\'t go anywhere. It may be old or mistyped.';

  @override
  String get actionGoHome => 'Go to Home';

  @override
  String get exploreHint => 'Search brands, food and card deals';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';
}
