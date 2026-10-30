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
  /// **'As on this phone'**
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

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Onboarding progress, read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Every sale in Pakistan, in one place.'**
  String get welcomeTitle;

  /// Shown on the first screen under the logo, together with the other language's version.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get welcomeLanguagePrompt;

  /// The language prompt in the OTHER language (Urdu in the English file, English in the Urdu file), so both readers understand the first screen.
  ///
  /// In en, this message translates to:
  /// **'اپنی زبان منتخب کریں'**
  String get welcomeLanguagePromptOther;

  /// No description provided for @cityTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you shop?'**
  String get cityTitle;

  /// No description provided for @cityBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show deals from your city. Nationwide and online deals show everywhere.'**
  String get cityBody;

  /// No description provided for @actionDetectCity.
  ///
  /// In en, this message translates to:
  /// **'Detect my city'**
  String get actionDetectCity;

  /// No description provided for @cityDetecting.
  ///
  /// In en, this message translates to:
  /// **'Finding your city…'**
  String get cityDetecting;

  /// No description provided for @cityDetected.
  ///
  /// In en, this message translates to:
  /// **'You\'re in {city}.'**
  String cityDetected(String city);

  /// No description provided for @cityNotCovered.
  ///
  /// In en, this message translates to:
  /// **'Your location isn\'t near a city we cover yet. Pick one below.'**
  String get cityNotCovered;

  /// No description provided for @cityLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'No problem. Pick your city below.'**
  String get cityLocationDenied;

  /// No description provided for @cityLocationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is off for this app. Turn it on in settings, or pick your city below.'**
  String get cityLocationBlocked;

  /// No description provided for @cityLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s location is off. Pick your city below.'**
  String get cityLocationOff;

  /// No description provided for @cityLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your location. Pick your city below.'**
  String get cityLocationUnavailable;

  /// Under a city whose local deals are not live yet.
  ///
  /// In en, this message translates to:
  /// **'Local deals coming soon'**
  String get cityLocalSoon;

  /// No description provided for @interestsTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get interestsTitle;

  /// No description provided for @interestsBody.
  ///
  /// In en, this message translates to:
  /// **'Pick 3 or more to tune your feed. You can change them later.'**
  String get interestsBody;

  /// No description provided for @interestsPicked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None picked yet} =1{1 picked} other{{count} picked}}'**
  String interestsPicked(int count);

  /// No description provided for @brandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Favourite brands'**
  String get brandsTitle;

  /// No description provided for @brandsBody.
  ///
  /// In en, this message translates to:
  /// **'Follow brands to hear first when their sale is on.'**
  String get brandsBody;

  /// No description provided for @brandsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No brands here yet. You can follow brands later from Explore.'**
  String get brandsEmpty;

  /// No description provided for @brandsFollowed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Following none yet} =1{Following 1 brand} other{Following {count} brands}}'**
  String brandsFollowed(int count);

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Be first to know'**
  String get alertsTitle;

  /// No description provided for @alertsBody.
  ///
  /// In en, this message translates to:
  /// **'Get an alert when a brand you follow starts a sale.'**
  String get alertsBody;

  /// No description provided for @alertsExampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Example alert'**
  String get alertsExampleLabel;

  /// No description provided for @alertsExampleTitle.
  ///
  /// In en, this message translates to:
  /// **'Threads: up to 50% off'**
  String get alertsExampleTitle;

  /// No description provided for @alertsExampleBody.
  ///
  /// In en, this message translates to:
  /// **'Winter collection sale, ends Sunday'**
  String get alertsExampleBody;

  /// No description provided for @alertsPromiseCap.
  ///
  /// In en, this message translates to:
  /// **'At most 3 alerts a day'**
  String get alertsPromiseCap;

  /// No description provided for @alertsPromiseQuiet.
  ///
  /// In en, this message translates to:
  /// **'Never at night (10 pm to 8 am)'**
  String get alertsPromiseQuiet;

  /// No description provided for @alertsPromiseTopics.
  ///
  /// In en, this message translates to:
  /// **'Choose what you hear about in Settings'**
  String get alertsPromiseTopics;

  /// No description provided for @alertsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Alerts are blocked for this app. You can turn them on in settings.'**
  String get alertsBlocked;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your saves and followed brands on any phone. No password: we text you a code.'**
  String get signInBody;

  /// No description provided for @reauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get reauthTitle;

  /// No description provided for @reauthBody.
  ///
  /// In en, this message translates to:
  /// **'For your safety, sign in again before deleting your account.'**
  String get reauthBody;

  /// No description provided for @reauthOtherNumber.
  ///
  /// In en, this message translates to:
  /// **'Use this account\'s own number to confirm it\'s you.'**
  String get reauthOtherNumber;

  /// No description provided for @reauthWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'That\'s a different account, so nothing was deleted. You\'ve been signed out.'**
  String get reauthWrongAccount;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'0300 1234567'**
  String get phoneHint;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a Pakistani mobile number, like 0300 1234567.'**
  String get phoneInvalid;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get actionSendCode;

  /// No description provided for @signInOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signInOr;

  /// No description provided for @actionContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get actionContinueWithGoogle;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeTitle;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String codeSentTo(String phone);

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check it, or send a new one.'**
  String get codeInvalid;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Send a new code in 1 second} other{Send a new code in {seconds} seconds}}'**
  String resendIn(int seconds);

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get actionResendCode;

  /// No description provided for @actionChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get actionChangeNumber;

  /// No description provided for @signInTerms.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms and Privacy Policy.'**
  String get signInTerms;

  /// No description provided for @signedInToast.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in.'**
  String get signedInToast;

  /// No description provided for @profileGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your saves on any phone'**
  String get profileGuestTitle;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @profileSignedInPhone.
  ///
  /// In en, this message translates to:
  /// **'Signed in with your phone'**
  String get profileSignedInPhone;

  /// No description provided for @profileSignedInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get profileSignedInGoogle;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @signedOutToast.
  ///
  /// In en, this message translates to:
  /// **'Signed out. Your saved deals, cards and follows come back when you sign in.'**
  String get signedOutToast;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @actionDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get actionDeleteAccount;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account'**
  String get deleteTitle;

  /// No description provided for @deleteIntro.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account and everything in it. It can\'t be undone.'**
  String get deleteIntro;

  /// No description provided for @deleteListTitle.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted'**
  String get deleteListTitle;

  /// No description provided for @deleteItemProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile and how you sign in'**
  String get deleteItemProfile;

  /// No description provided for @deleteItemSaves.
  ///
  /// In en, this message translates to:
  /// **'Saved deals, followed brands and your cards'**
  String get deleteItemSaves;

  /// No description provided for @deleteItemAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts, notifications and your devices'**
  String get deleteItemAlerts;

  /// No description provided for @deleteItemPhotos.
  ///
  /// In en, this message translates to:
  /// **'Your profile picture and the photos you sent'**
  String get deleteItemPhotos;

  /// No description provided for @deleteKept.
  ///
  /// In en, this message translates to:
  /// **'Deals you submitted stay up, without your name. Businesses keep their own pages.'**
  String get deleteKept;

  /// No description provided for @actionDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get actionDeleteForever;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out, and this phone starts fresh.'**
  String get deleteConfirmBody;

  /// No description provided for @deletedToast.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deletedToast;

  /// No description provided for @homeFeaturedTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get homeFeaturedTitle;

  /// No description provided for @homeTrendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending today'**
  String get homeTrendingTitle;

  /// No description provided for @homeNearTitle.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get homeNearTitle;

  /// No description provided for @homeEndingTitle.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get homeEndingTitle;

  /// No description provided for @homeForYouTitle.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get homeForYouTitle;

  /// No description provided for @homeNearBody.
  ///
  /// In en, this message translates to:
  /// **'See sales close to where you are. We use your location once and don\'t keep it.'**
  String get homeNearBody;

  /// No description provided for @actionShowNearby.
  ///
  /// In en, this message translates to:
  /// **'Show deals near me'**
  String get actionShowNearby;

  /// No description provided for @homeNearLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding deals near you…'**
  String get homeNearLocating;

  /// No description provided for @homeNearNoLocation.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t get your location. Pick your city to see local deals.'**
  String get homeNearNoLocation;

  /// No description provided for @homeNearBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is off for this app. Turn it on in settings, or pick your city.'**
  String get homeNearBlocked;

  /// No description provided for @homeFeedEnd.
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen all the new deals. Check back soon.'**
  String get homeFeedEnd;

  /// No description provided for @homeFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No deals here yet. Pick more interests or another city.'**
  String get homeFeedEmpty;

  /// No description provided for @actionChangeCity.
  ///
  /// In en, this message translates to:
  /// **'Change city'**
  String get actionChangeCity;

  /// Screen-reader label of the city button in the home app bar.
  ///
  /// In en, this message translates to:
  /// **'Deals in {city}'**
  String homeCityLabel(String city);

  /// No description provided for @distanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(String meters);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @dealEndedBanner.
  ///
  /// In en, this message translates to:
  /// **'This deal has ended. It\'s kept here so links to it still work.'**
  String get dealEndedBanner;

  /// No description provided for @dealStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String dealStartsOn(String date);

  /// No description provided for @dealPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get dealPromoCode;

  /// No description provided for @actionCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get actionCopyCode;

  /// No description provided for @codeCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Code copied.'**
  String get codeCopiedToast;

  /// No description provided for @dealAbout.
  ///
  /// In en, this message translates to:
  /// **'About this deal'**
  String get dealAbout;

  /// No description provided for @dealTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get dealTerms;

  /// No description provided for @dealWhere.
  ///
  /// In en, this message translates to:
  /// **'Where to use it'**
  String get dealWhere;

  /// No description provided for @dealOnlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Online only: use it on the brand\'s website or app.'**
  String get dealOnlineOnly;

  /// No description provided for @dealEverywhere.
  ///
  /// In en, this message translates to:
  /// **'At the brand\'s outlets across Pakistan.'**
  String get dealEverywhere;

  /// No description provided for @dealNoOutlets.
  ///
  /// In en, this message translates to:
  /// **'Ask at your nearest outlet.'**
  String get dealNoOutlets;

  /// No description provided for @actionDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get actionDirections;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionCall;

  /// No description provided for @actionSeeSource.
  ///
  /// In en, this message translates to:
  /// **'See the source'**
  String get actionSeeSource;

  /// No description provided for @actionOpenOffer.
  ///
  /// In en, this message translates to:
  /// **'Open the offer'**
  String get actionOpenOffer;

  /// No description provided for @dealCards.
  ///
  /// In en, this message translates to:
  /// **'With these cards'**
  String get dealCards;

  /// No description provided for @actionReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get actionReportProblem;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong with this deal?'**
  String get reportTitle;

  /// No description provided for @reportExpired.
  ///
  /// In en, this message translates to:
  /// **'It has ended'**
  String get reportExpired;

  /// No description provided for @reportWrongPrice.
  ///
  /// In en, this message translates to:
  /// **'The price or discount is wrong'**
  String get reportWrongPrice;

  /// No description provided for @reportWrongPlace.
  ///
  /// In en, this message translates to:
  /// **'It isn\'t at this place'**
  String get reportWrongPlace;

  /// No description provided for @reportClosed.
  ///
  /// In en, this message translates to:
  /// **'The shop is closed'**
  String get reportClosed;

  /// No description provided for @reportSpam.
  ///
  /// In en, this message translates to:
  /// **'It\'s spam or fake'**
  String get reportSpam;

  /// No description provided for @reportOffensive.
  ///
  /// In en, this message translates to:
  /// **'It\'s offensive'**
  String get reportOffensive;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// No description provided for @reportNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell us more (optional)'**
  String get reportNoteLabel;

  /// No description provided for @reportNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Please say what\'s wrong.'**
  String get reportNoteRequired;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We\'ll check it.'**
  String get reportThanks;

  /// No description provided for @reportAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reported this deal. Thanks!'**
  String get reportAlready;

  /// No description provided for @reportSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report a deal, so we can stop fake reports.'**
  String get reportSignIn;

  /// WhatsApp share text. Brand, offer and title are already localized.
  ///
  /// In en, this message translates to:
  /// **'{brand}: {offer}. {title}. Found on Sale Lagi Hai!'**
  String shareDealText(String brand, String offer, String title);

  /// No description provided for @savedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get savedToast;

  /// No description provided for @unsavedToast.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved.'**
  String get unsavedToast;

  /// No description provided for @linkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that. Try again later.'**
  String get linkFailed;

  /// No description provided for @exploreCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get exploreCategories;

  /// No description provided for @exploreBrands.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get exploreBrands;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @brandVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified brand'**
  String get brandVerified;

  /// No description provided for @actionVisitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit website'**
  String get actionVisitWebsite;

  /// No description provided for @brandNoDeals.
  ///
  /// In en, this message translates to:
  /// **'No live deals from this brand right now. Follow it to hear when the next one starts.'**
  String get brandNoDeals;

  /// No description provided for @categoryNoDeals.
  ///
  /// In en, this message translates to:
  /// **'No live deals here right now. Follow this category to hear when one starts.'**
  String get categoryNoDeals;

  /// No description provided for @followedToast.
  ///
  /// In en, this message translates to:
  /// **'Following {name}. We\'ll tell you when a sale starts.'**
  String followedToast(String name);

  /// No description provided for @unfollowedToast.
  ///
  /// In en, this message translates to:
  /// **'Stopped following {name}.'**
  String unfollowedToast(String name);

  /// Screen-reader label of a follow button.
  ///
  /// In en, this message translates to:
  /// **'Follow {name}'**
  String followLabel(String name);

  /// No description provided for @listEnd.
  ///
  /// In en, this message translates to:
  /// **'That\'s every live deal here.'**
  String get listEnd;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search deals'**
  String get searchFieldLabel;

  /// No description provided for @actionClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get actionClearSearch;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @actionClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get actionClearRecent;

  /// No description provided for @actionRemoveRecent.
  ///
  /// In en, this message translates to:
  /// **'Remove “⁨{query}⁩”'**
  String actionRemoveRecent(String query);

  /// No description provided for @searchRecentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Recent searches stay on this phone.'**
  String get searchRecentPrivacy;

  /// No description provided for @searchPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular categories'**
  String get searchPopular;

  /// No description provided for @searchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get searchSuggestions;

  /// No description provided for @searchKindBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get searchKindBrand;

  /// No description provided for @searchKindCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get searchKindCategory;

  /// No description provided for @searchKindArea.
  ///
  /// In en, this message translates to:
  /// **'Area: show deals here'**
  String get searchKindArea;

  /// No description provided for @searchDeals.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get searchDeals;

  /// No description provided for @searchNoFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No deals match these filters. Try fewer filters.'**
  String get searchNoFilterResults;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// The filters button when some are on.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersOn(int count);

  /// No description provided for @filterArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get filterArea;

  /// No description provided for @filterAnyArea.
  ///
  /// In en, this message translates to:
  /// **'Anywhere'**
  String get filterAnyArea;

  /// No description provided for @filterAreaNeedsCity.
  ///
  /// In en, this message translates to:
  /// **'Choose a city on Home to filter by area.'**
  String get filterAreaNeedsCity;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterBank.
  ///
  /// In en, this message translates to:
  /// **'Card offers from'**
  String get filterBank;

  /// No description provided for @filterDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get filterDiscount;

  /// No description provided for @filterAnyDiscount.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAnyDiscount;

  /// No description provided for @filterMinPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%+ off'**
  String filterMinPercent(String percent);

  /// No description provided for @filterEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get filterEndingSoon;

  /// No description provided for @filterEndingSoonHint.
  ///
  /// In en, this message translates to:
  /// **'Ends within 3 days'**
  String get filterEndingSoonHint;

  /// No description provided for @actionShowDeals.
  ///
  /// In en, this message translates to:
  /// **'Show deals'**
  String get actionShowDeals;

  /// No description provided for @myCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get myCardsTitle;

  /// No description provided for @myCardsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We never ask for card numbers: only your bank and card type. Your cards stay on this phone, and in your account if you sign in.'**
  String get myCardsPrivacy;

  /// No description provided for @myCardsYours.
  ///
  /// In en, this message translates to:
  /// **'Your cards'**
  String get myCardsYours;

  /// No description provided for @myCardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add your cards to see the discounts they get you.'**
  String get myCardsEmpty;

  /// No description provided for @myCardsDeals.
  ///
  /// In en, this message translates to:
  /// **'Offers for your cards'**
  String get myCardsDeals;

  /// No description provided for @myCardsNoDeals.
  ///
  /// In en, this message translates to:
  /// **'No live offers for your cards right now. We\'ll show them here when they start.'**
  String get myCardsNoDeals;

  /// No description provided for @myCardsFull.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} cards. Remove one to add another.'**
  String myCardsFull(int count);

  /// No description provided for @myCardsEntry.
  ///
  /// In en, this message translates to:
  /// **'My cards: see your card discounts'**
  String get myCardsEntry;

  /// No description provided for @actionAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add a card'**
  String get actionAddCard;

  /// No description provided for @actionRemoveCard.
  ///
  /// In en, this message translates to:
  /// **'Remove {card}'**
  String actionRemoveCard(String card);

  /// No description provided for @addCardPickBank.
  ///
  /// In en, this message translates to:
  /// **'Which bank?'**
  String get addCardPickBank;

  /// No description provided for @addCardPickType.
  ///
  /// In en, this message translates to:
  /// **'Which {bank} card?'**
  String addCardPickType(String bank);

  /// No description provided for @cardAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get cardAlreadyAdded;

  /// No description provided for @cardAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Added {card}'**
  String cardAddedToast(String card);

  /// No description provided for @cardRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Removed {card}'**
  String cardRemovedToast(String card);

  /// A card as the shopper picked it: bank short name, product name, and Credit/Debit/Prepaid.
  ///
  /// In en, this message translates to:
  /// **'{bank} {product} ({kind})'**
  String cardName(String bank, String product, String kind);

  /// No description provided for @cardKindCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get cardKindCredit;

  /// No description provided for @cardKindDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get cardKindDebit;

  /// No description provided for @cardKindPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get cardKindPrepaid;

  /// No description provided for @emptySearchNoFilters.
  ///
  /// In en, this message translates to:
  /// **'No deals for “⁨{query}⁩”. Try another word.'**
  String emptySearchNoFilters(String query);

  /// No description provided for @savedActive.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String savedActive(int count);

  /// No description provided for @savedEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended ({count})'**
  String savedEnded(int count);

  /// No description provided for @savedNoEnded.
  ///
  /// In en, this message translates to:
  /// **'None of your saved deals has ended.'**
  String get savedNoEnded;

  /// No description provided for @savedNoActive.
  ///
  /// In en, this message translates to:
  /// **'None of your saved deals is on right now.'**
  String get savedNoActive;

  /// No description provided for @savedGone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved deal is no longer available.} other{{count} saved deals are no longer available.}}'**
  String savedGone(int count);

  /// No description provided for @actionRemoveThem.
  ///
  /// In en, this message translates to:
  /// **'Remove them'**
  String get actionRemoveThem;

  /// No description provided for @actionRemoveEnded.
  ///
  /// In en, this message translates to:
  /// **'Remove ended deals'**
  String get actionRemoveEnded;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @alertJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get alertJustNow;

  /// No description provided for @alertMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String alertMinutesAgo(int count);

  /// No description provided for @alertHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String alertHoursAgo(int count);

  /// No description provided for @alertYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get alertYesterday;

  /// No description provided for @alertUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get alertUnread;

  /// No description provided for @alertsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get alertsToday;

  /// No description provided for @alertsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get alertsEarlier;

  /// No description provided for @actionMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get actionMarkAllRead;

  /// No description provided for @alertsGuest.
  ///
  /// In en, this message translates to:
  /// **'Sign in to get alerts here, on every phone you use. Follows work without an account too.'**
  String get alertsGuest;

  /// No description provided for @followingTitle.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingTitle;

  /// No description provided for @followingSummary.
  ///
  /// In en, this message translates to:
  /// **'{brands, plural, =0{No brands} =1{1 brand} other{{brands} brands}} · {categories, plural, =0{no categories} =1{1 category} other{{categories} categories}}'**
  String followingSummary(int brands, int categories);

  /// No description provided for @followingBrands.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get followingBrands;

  /// No description provided for @followingCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get followingCategories;

  /// No description provided for @followingEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re not following anything yet. Follow brands and categories to hear about their deals.'**
  String get followingEmpty;

  /// No description provided for @actionExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore brands'**
  String get actionExplore;

  /// No description provided for @alertsBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new alert} other{{count} new alerts}}'**
  String alertsBadge(int count);

  /// No description provided for @alertsBadgeMany.
  ///
  /// In en, this message translates to:
  /// **'More than 99 new alerts'**
  String get alertsBadgeMany;

  /// No description provided for @reportNoteCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Please leave out card numbers. We never need them.'**
  String get reportNoteCardNumber;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get settingsCity;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicenses;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get aboutContact;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Every sale in Pakistan, in one place.'**
  String get aboutTagline;

  /// No description provided for @notifSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to choose which alerts you get. Follows work without an account too.'**
  String get notifSignIn;

  /// No description provided for @notifPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPush;

  /// No description provided for @notifPushHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts on this phone, as well as in the inbox.'**
  String get notifPushHint;

  /// No description provided for @notifBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in your phone\'s settings.'**
  String get notifBlocked;

  /// No description provided for @notifTopics.
  ///
  /// In en, this message translates to:
  /// **'What to tell you about'**
  String get notifTopics;

  /// No description provided for @topicBrands.
  ///
  /// In en, this message translates to:
  /// **'Brands you follow'**
  String get topicBrands;

  /// No description provided for @topicCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories you follow'**
  String get topicCategories;

  /// No description provided for @topicCards.
  ///
  /// In en, this message translates to:
  /// **'Offers for your cards'**
  String get topicCards;

  /// No description provided for @topicCity.
  ///
  /// In en, this message translates to:
  /// **'New deals in your city'**
  String get topicCity;

  /// No description provided for @topicPriceDrops.
  ///
  /// In en, this message translates to:
  /// **'Price drops on saved deals'**
  String get topicPriceDrops;

  /// No description provided for @topicExpiring.
  ///
  /// In en, this message translates to:
  /// **'Saved deals ending soon'**
  String get topicExpiring;

  /// No description provided for @notifFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get notifFrequency;

  /// No description provided for @freqLow.
  ///
  /// In en, this message translates to:
  /// **'At most 1 a day'**
  String get freqLow;

  /// No description provided for @freqNormal.
  ///
  /// In en, this message translates to:
  /// **'At most 3 a day'**
  String get freqNormal;

  /// No description provided for @freqHigh.
  ///
  /// In en, this message translates to:
  /// **'At most 6 a day'**
  String get freqHigh;

  /// No description provided for @notifQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notifQuiet;

  /// No description provided for @quietFrom.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String quietFrom(String time);

  /// No description provided for @quietTo.
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String quietTo(String time);

  /// No description provided for @quietHint.
  ///
  /// In en, this message translates to:
  /// **'No pushes in these hours (Pakistan time). They wait until the morning.'**
  String get quietHint;

  /// No description provided for @quietSame.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours need a different start and end.'**
  String get quietSame;

  /// No description provided for @notifSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that. Try again.'**
  String get notifSaveFailed;

  /// No description provided for @notifQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. It will be sent when you are back online.'**
  String get notifQueued;

  /// No description provided for @privacyOnPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get privacyOnPhone;

  /// No description provided for @privacyOnPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your language, city, follows, saved deals, recent searches and cards. Your approximate location is used only for \"Near you\", and never stored.'**
  String get privacyOnPhoneBody;

  /// No description provided for @privacyInAccount.
  ///
  /// In en, this message translates to:
  /// **'In your account'**
  String get privacyInAccount;

  /// No description provided for @privacyInAccountBody.
  ///
  /// In en, this message translates to:
  /// **'If you sign in: the same choices, so they follow you to another phone, plus your alert settings and alerts.'**
  String get privacyInAccountBody;

  /// No description provided for @privacyNever.
  ///
  /// In en, this message translates to:
  /// **'Never: card numbers, your exact location, or anything sold to brands.'**
  String get privacyNever;

  /// No description provided for @actionClearSearches.
  ///
  /// In en, this message translates to:
  /// **'Clear recent searches'**
  String get actionClearSearches;

  /// No description provided for @actionClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear saved copies of deals'**
  String get actionClearCache;

  /// No description provided for @actionClearPhone.
  ///
  /// In en, this message translates to:
  /// **'Clear everything on this phone'**
  String get actionClearPhone;

  /// No description provided for @clearPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this phone?'**
  String get clearPhoneTitle;

  /// No description provided for @clearPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your choices, follows, saved deals and cards on this phone are removed, and you are signed out. What is in your account stays.'**
  String get clearPhoneBody;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @clearedToast.
  ///
  /// In en, this message translates to:
  /// **'Cleared.'**
  String get clearedToast;
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
