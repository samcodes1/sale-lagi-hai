import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  /// App name. Do not translate the brand; the Urdu file uses the Urdu wordmark spelling.
  ///
  /// In en, this message translates to:
  /// **'Sale Lagi Hai!'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'First to know when the sale is on.'**
  String get appTagline;

  /// Bottom navigation tab label. Keep short (one word).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get actionUnsave;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionShareWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get actionShareWhatsApp;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @actionClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get actionClearFilters;

  /// No description provided for @actionSetAlert.
  ///
  /// In en, this message translates to:
  /// **'Set alert'**
  String get actionSetAlert;

  /// No description provided for @actionTurnOnAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn on alerts'**
  String get actionTurnOnAlerts;

  /// No description provided for @actionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// No description provided for @actionFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get actionFollow;

  /// No description provided for @actionFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get actionFollowing;

  /// No description provided for @actionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get actionReport;

  /// No description provided for @actionViewTerms.
  ///
  /// In en, this message translates to:
  /// **'View terms'**
  String get actionViewTerms;

  /// No description provided for @actionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @actionPickArea.
  ///
  /// In en, this message translates to:
  /// **'Pick your area'**
  String get actionPickArea;

  /// Screen-reader label for skeleton placeholders.
  ///
  /// In en, this message translates to:
  /// **'Loading deals'**
  String get loadingDeals;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet. Your saved deals still work; new ones will load when you\'re back.'**
  String get offlineBanner;

  /// No description provided for @updatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Updated just now} =1{Updated 1 minute ago} other{Updated {count} minutes ago}}'**
  String updatedMinutesAgo(int count);

  /// No description provided for @updatedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 hour ago} other{Updated {count} hours ago}}'**
  String updatedHoursAgo(int count);

  /// No description provided for @updatedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated yesterday} other{Updated {count} days ago}}'**
  String updatedDaysAgo(int count);

  /// No description provided for @verifiedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Verified just now} =1{Verified 1 minute ago} other{Verified {count} minutes ago}}'**
  String verifiedMinutesAgo(int count);

  /// No description provided for @verifiedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Verified 1 hour ago} other{Verified {count} hours ago}}'**
  String verifiedHoursAgo(int count);

  /// No description provided for @verifiedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Verified yesterday} other{Verified {count} days ago}}'**
  String verifiedDaysAgo(int count);

  /// No description provided for @endsInHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ends in 1 hour} other{Ends in {count} hours}}'**
  String endsInHours(int count);

  /// No description provided for @endsInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ends tomorrow} other{Ends in {count} days}}'**
  String endsInDays(int count);

  /// No description provided for @endsToday.
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get endsToday;

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String endsOn(String date);

  /// No description provided for @dealOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get dealOngoing;

  /// No description provided for @dealExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get dealExpired;

  /// Label on paid placements. Must always be shown on sponsored deals.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredLabel;

  /// Discount badge. In RTL locales wrap it in an LTR isolate (U+2066 … U+2069) so the sign stays in front.
  ///
  /// In en, this message translates to:
  /// **'-{percent}%'**
  String discountBadge(int percent);

  /// No description provided for @flatPercentOff.
  ///
  /// In en, this message translates to:
  /// **'Flat {percent}% off'**
  String flatPercentOff(int percent);

  /// No description provided for @upToPercentOff.
  ///
  /// In en, this message translates to:
  /// **'Up to {percent}% off'**
  String upToPercentOff(int percent);

  /// No description provided for @priceRupees.
  ///
  /// In en, this message translates to:
  /// **'Rs {amount}'**
  String priceRupees(String amount);

  /// Screen-reader text for a struck-through old price and a new price.
  ///
  /// In en, this message translates to:
  /// **'was {oldPrice}, now {newPrice}'**
  String priceWasNow(String oldPrice, String newPrice);

  /// No description provided for @allPakistan.
  ///
  /// In en, this message translates to:
  /// **'All Pakistan'**
  String get allPakistan;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @emptyNearby.
  ///
  /// In en, this message translates to:
  /// **'Quiet day in the bazaar. No sales near you right now; we\'ll shout when one starts.'**
  String get emptyNearby;

  /// No description provided for @emptySaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. Tap the bookmark on a deal to keep it here.'**
  String get emptySaved;

  /// No description provided for @emptyAlerts.
  ///
  /// In en, this message translates to:
  /// **'Follow a brand and we\'ll tell you the moment its sale starts.'**
  String get emptyAlerts;

  /// No description provided for @emptySearch.
  ///
  /// In en, this message translates to:
  /// **'No deals for “⁨{query}⁩”. Try another word or clear the filters.'**
  String emptySearch(String query);

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Allow location to see deals near you, or pick your area.'**
  String get locationOff;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Check your connection and try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Try again in a minute.'**
  String get errorServer;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this. It may have ended.'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Some details need fixing. Check the highlighted fields.'**
  String get errorValidation;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorStorage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save on this phone. Free up some space and try again.'**
  String get errorStorage;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnexpected;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @dealTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get dealTitle;

  /// No description provided for @brandTitle.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brandTitle;

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// Shown for unknown links. Never include the link itself: it may contain anything.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t go anywhere. It may be old or mistyped.'**
  String get notFoundBody;

  /// No description provided for @actionGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get actionGoHome;

  /// No description provided for @exploreHint.
  ///
  /// In en, this message translates to:
  /// **'Search brands, food and card deals'**
  String get exploreHint;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Always shown in its own script in both languages.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
