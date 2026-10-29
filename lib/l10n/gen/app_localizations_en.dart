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

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionBack => 'Back';

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get welcomeTitle => 'Every sale in Pakistan, in one place.';

  @override
  String get welcomeLanguagePrompt => 'Choose your language';

  @override
  String get welcomeLanguagePromptOther => 'اپنی زبان منتخب کریں';

  @override
  String get cityTitle => 'Where do you shop?';

  @override
  String get cityBody =>
      'We\'ll show deals from your city. Nationwide and online deals show everywhere.';

  @override
  String get actionDetectCity => 'Detect my city';

  @override
  String get cityDetecting => 'Finding your city…';

  @override
  String cityDetected(String city) {
    return 'You\'re in $city.';
  }

  @override
  String get cityNotCovered =>
      'Your location isn\'t near a city we cover yet. Pick one below.';

  @override
  String get cityLocationDenied => 'No problem. Pick your city below.';

  @override
  String get cityLocationBlocked =>
      'Location is off for this app. Turn it on in settings, or pick your city below.';

  @override
  String get cityLocationOff =>
      'Your phone\'s location is off. Pick your city below.';

  @override
  String get cityLocationUnavailable =>
      'We couldn\'t find your location. Pick your city below.';

  @override
  String get cityLocalSoon => 'Local deals coming soon';

  @override
  String get interestsTitle => 'What are you into?';

  @override
  String get interestsBody =>
      'Pick 3 or more to tune your feed. You can change them later.';

  @override
  String interestsPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count picked',
      one: '1 picked',
      zero: 'None picked yet',
    );
    return '$_temp0';
  }

  @override
  String get brandsTitle => 'Favourite brands';

  @override
  String get brandsBody => 'Follow brands to hear first when their sale is on.';

  @override
  String get brandsEmpty =>
      'No brands here yet. You can follow brands later from Explore.';

  @override
  String brandsFollowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following $count brands',
      one: 'Following 1 brand',
      zero: 'Following none yet',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'Be first to know';

  @override
  String get alertsBody =>
      'Get an alert when a brand you follow starts a sale.';

  @override
  String get alertsExampleLabel => 'Example alert';

  @override
  String get alertsExampleTitle => 'Threads: up to 50% off';

  @override
  String get alertsExampleBody => 'Winter collection sale, ends Sunday';

  @override
  String get alertsPromiseCap => 'At most 3 alerts a day';

  @override
  String get alertsPromiseQuiet => 'Never at night (10 pm to 8 am)';

  @override
  String get alertsPromiseTopics => 'Choose what you hear about in Settings';

  @override
  String get alertsBlocked =>
      'Alerts are blocked for this app. You can turn them on in settings.';

  @override
  String get signInTitle => 'Sign in to sync';

  @override
  String get signInBody =>
      'Keep your saves and followed brands on any phone. No password: we text you a code.';

  @override
  String get reauthTitle => 'Confirm it\'s you';

  @override
  String get reauthBody =>
      'For your safety, sign in again before deleting your account.';

  @override
  String get reauthOtherNumber =>
      'Use this account\'s own number to confirm it\'s you.';

  @override
  String get reauthWrongAccount =>
      'That\'s a different account, so nothing was deleted. You\'ve been signed out.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHint => '0300 1234567';

  @override
  String get phoneInvalid =>
      'Enter a Pakistani mobile number, like 0300 1234567.';

  @override
  String get actionSendCode => 'Send code';

  @override
  String get signInOr => 'or';

  @override
  String get actionContinueWithGoogle => 'Continue with Google';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeSentTo(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get codeLabel => '6-digit code';

  @override
  String get codeInvalid =>
      'That code is wrong or has expired. Check it, or send a new one.';

  @override
  String resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Send a new code in $seconds seconds',
      one: 'Send a new code in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get actionResendCode => 'Send a new code';

  @override
  String get actionChangeNumber => 'Change number';

  @override
  String get signInTerms =>
      'By continuing, you agree to our Terms and Privacy Policy.';

  @override
  String get signedInToast => 'You\'re signed in.';

  @override
  String get profileGuestTitle => 'Sign in to keep your saves on any phone';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get profileSignedInPhone => 'Signed in with your phone';

  @override
  String get profileSignedInGoogle => 'Signed in with Google';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get signedOutToast => 'Signed out. Your choices stay on this phone.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get actionDeleteAccount => 'Delete account';

  @override
  String get deleteTitle => 'Delete your account';

  @override
  String get deleteIntro =>
      'This deletes your account and everything in it. It can\'t be undone.';

  @override
  String get deleteListTitle => 'What gets deleted';

  @override
  String get deleteItemProfile => 'Your profile and how you sign in';

  @override
  String get deleteItemSaves => 'Saved deals, followed brands and your cards';

  @override
  String get deleteItemAlerts => 'Alerts, notifications and your devices';

  @override
  String get deleteItemPhotos => 'Your profile picture and the photos you sent';

  @override
  String get deleteKept =>
      'Deals you submitted stay up, without your name. Businesses keep their own pages.';

  @override
  String get actionDeleteForever => 'Delete my account';

  @override
  String get deleteConfirmTitle => 'Delete your account?';

  @override
  String get deleteConfirmBody =>
      'You\'ll be signed out, and this phone starts fresh.';

  @override
  String get deletedToast => 'Your account was deleted.';

  @override
  String get homeFeaturedTitle => 'Featured';

  @override
  String get homeTrendingTitle => 'Trending today';

  @override
  String get homeNearTitle => 'Near you';

  @override
  String get homeEndingTitle => 'Ending soon';

  @override
  String get homeForYouTitle => 'For you';

  @override
  String get homeNearBody =>
      'See sales close to where you are. We use your location once and don\'t keep it.';

  @override
  String get actionShowNearby => 'Show deals near me';

  @override
  String get homeNearLocating => 'Finding deals near you…';

  @override
  String get homeNearNoLocation =>
      'We couldn\'t get your location. Pick your city to see local deals.';

  @override
  String get homeNearBlocked =>
      'Location is off for this app. Turn it on in settings, or pick your city.';

  @override
  String get homeFeedEnd => 'You\'ve seen all the new deals. Check back soon.';

  @override
  String get homeFeedEmpty =>
      'No deals here yet. Pick more interests or another city.';

  @override
  String get actionChangeCity => 'Change city';

  @override
  String homeCityLabel(String city) {
    return 'Deals in $city';
  }

  @override
  String distanceMeters(String meters) {
    return '$meters m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get dealEndedBanner =>
      'This deal has ended. It\'s kept here so links to it still work.';

  @override
  String dealStartsOn(String date) {
    return 'Starts $date';
  }

  @override
  String get dealPromoCode => 'Promo code';

  @override
  String get actionCopyCode => 'Copy code';

  @override
  String get codeCopiedToast => 'Code copied.';

  @override
  String get dealAbout => 'About this deal';

  @override
  String get dealTerms => 'Terms';

  @override
  String get dealWhere => 'Where to use it';

  @override
  String get dealOnlineOnly =>
      'Online only: use it on the brand\'s website or app.';

  @override
  String get dealEverywhere => 'At the brand\'s outlets across Pakistan.';

  @override
  String get dealNoOutlets => 'Ask at your nearest outlet.';

  @override
  String get actionDirections => 'Directions';

  @override
  String get actionCall => 'Call';

  @override
  String get actionSeeSource => 'See the source';

  @override
  String get actionOpenOffer => 'Open the offer';

  @override
  String get dealCards => 'With these cards';

  @override
  String get actionReportProblem => 'Report a problem';

  @override
  String get reportTitle => 'What\'s wrong with this deal?';

  @override
  String get reportExpired => 'It has ended';

  @override
  String get reportWrongPrice => 'The price or discount is wrong';

  @override
  String get reportWrongPlace => 'It isn\'t at this place';

  @override
  String get reportClosed => 'The shop is closed';

  @override
  String get reportSpam => 'It\'s spam or fake';

  @override
  String get reportOffensive => 'It\'s offensive';

  @override
  String get reportOther => 'Something else';

  @override
  String get reportNoteLabel => 'Tell us more (optional)';

  @override
  String get reportNoteRequired => 'Please say what\'s wrong.';

  @override
  String get actionSend => 'Send';

  @override
  String get reportThanks => 'Thanks. We\'ll check it.';

  @override
  String get reportAlready => 'You\'ve already reported this deal. Thanks!';

  @override
  String get reportSignIn =>
      'Sign in to report a deal, so we can stop fake reports.';

  @override
  String shareDealText(String brand, String offer, String title) {
    return '$brand: $offer. $title. Found on Sale Lagi Hai!';
  }

  @override
  String get savedToast => 'Saved.';

  @override
  String get unsavedToast => 'Removed from saved.';

  @override
  String get linkFailed => 'Couldn\'t open that. Try again later.';

  @override
  String get exploreCategories => 'Categories';

  @override
  String get exploreBrands => 'Brands';

  @override
  String get categoryAll => 'All';

  @override
  String get brandVerified => 'Verified brand';

  @override
  String get actionVisitWebsite => 'Visit website';

  @override
  String get brandNoDeals =>
      'No live deals from this brand right now. Follow it to hear when the next one starts.';

  @override
  String get categoryNoDeals =>
      'No live deals here right now. Follow this category to hear when one starts.';

  @override
  String followedToast(String name) {
    return 'Following $name. We\'ll tell you when a sale starts.';
  }

  @override
  String unfollowedToast(String name) {
    return 'Stopped following $name.';
  }

  @override
  String followLabel(String name) {
    return 'Follow $name';
  }

  @override
  String get listEnd => 'That\'s every live deal here.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchFieldLabel => 'Search deals';

  @override
  String get actionClearSearch => 'Clear search';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get actionClearRecent => 'Clear all';

  @override
  String actionRemoveRecent(String query) {
    return 'Remove “⁨$query⁩”';
  }

  @override
  String get searchRecentPrivacy => 'Recent searches stay on this phone.';

  @override
  String get searchPopular => 'Popular categories';

  @override
  String get searchSuggestions => 'Suggestions';

  @override
  String get searchKindBrand => 'Brand';

  @override
  String get searchKindCategory => 'Category';

  @override
  String get searchKindArea => 'Area: show deals here';

  @override
  String get searchDeals => 'Deals';

  @override
  String get searchNoFilterResults =>
      'No deals match these filters. Try fewer filters.';

  @override
  String get filtersTitle => 'Filters';

  @override
  String filtersOn(int count) {
    return 'Filters ($count)';
  }

  @override
  String get filterArea => 'Area';

  @override
  String get filterAnyArea => 'Anywhere';

  @override
  String get filterAreaNeedsCity => 'Choose a city on Home to filter by area.';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterBank => 'Card offers from';

  @override
  String get filterDiscount => 'Discount';

  @override
  String get filterAnyDiscount => 'Any';

  @override
  String filterMinPercent(String percent) {
    return '$percent%+ off';
  }

  @override
  String get filterEndingSoon => 'Ending soon';

  @override
  String get filterEndingSoonHint => 'Ends within 3 days';

  @override
  String get actionShowDeals => 'Show deals';

  @override
  String get myCardsTitle => 'My cards';

  @override
  String get myCardsPrivacy =>
      'We never ask for card numbers: only your bank and card type. Your cards stay on this phone, and in your account if you sign in.';

  @override
  String get myCardsYours => 'Your cards';

  @override
  String get myCardsEmpty =>
      'Add your cards to see the discounts they get you.';

  @override
  String get myCardsDeals => 'Offers for your cards';

  @override
  String get myCardsNoDeals =>
      'No live offers for your cards right now. We\'ll show them here when they start.';

  @override
  String myCardsFull(int count) {
    return 'You can add up to $count cards. Remove one to add another.';
  }

  @override
  String get myCardsEntry => 'My cards: see your card discounts';

  @override
  String get actionAddCard => 'Add a card';

  @override
  String actionRemoveCard(String card) {
    return 'Remove $card';
  }

  @override
  String get addCardPickBank => 'Which bank?';

  @override
  String addCardPickType(String bank) {
    return 'Which $bank card?';
  }

  @override
  String get cardAlreadyAdded => 'Already added';

  @override
  String cardAddedToast(String card) {
    return 'Added $card';
  }

  @override
  String cardRemovedToast(String card) {
    return 'Removed $card';
  }

  @override
  String cardName(String bank, String product, String kind) {
    return '$bank $product ($kind)';
  }

  @override
  String get cardKindCredit => 'Credit';

  @override
  String get cardKindDebit => 'Debit';

  @override
  String get cardKindPrepaid => 'Prepaid';
}
