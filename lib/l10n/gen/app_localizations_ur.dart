// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'سیل لگی ہے!';

  @override
  String get appTagline => 'سیل کی خبر، سب سے پہلے۔';

  @override
  String get navHome => 'ہوم';

  @override
  String get navExplore => 'تلاش';

  @override
  String get navAlerts => 'الرٹس';

  @override
  String get navSaved => 'محفوظ';

  @override
  String get navProfile => 'پروفائل';

  @override
  String get actionRetry => 'دوبارہ کوشش کریں';

  @override
  String get actionCancel => 'منسوخ کریں';

  @override
  String get actionClose => 'بند کریں';

  @override
  String get actionSave => 'محفوظ کریں';

  @override
  String get actionUnsave => 'محفوظ سے ہٹائیں';

  @override
  String get actionShare => 'شیئر کریں';

  @override
  String get actionShareWhatsApp => 'واٹس ایپ پر شیئر کریں';

  @override
  String get actionSeeAll => 'سب دیکھیں';

  @override
  String get actionClearFilters => 'فلٹر ہٹائیں';

  @override
  String get actionSetAlert => 'الرٹ لگائیں';

  @override
  String get actionTurnOnAlerts => 'الرٹس آن کریں';

  @override
  String get actionNotNow => 'ابھی نہیں';

  @override
  String get actionFollow => 'فالو کریں';

  @override
  String get actionFollowing => 'فالو کر رہے ہیں';

  @override
  String get actionReport => 'رپورٹ کریں';

  @override
  String get actionViewTerms => 'شرائط دیکھیں';

  @override
  String get actionOpenSettings => 'سیٹنگز کھولیں';

  @override
  String get actionPickArea => 'اپنا علاقہ چنیں';

  @override
  String get loadingDeals => 'ڈیلز لوڈ ہو رہی ہیں';

  @override
  String get offlineBanner =>
      'انٹرنیٹ نہیں چل رہا۔ محفوظ ڈیلز دستیاب ہیں، نئی ڈیلز آن لائن ہوتے ہی آ جائیں گی۔';

  @override
  String updatedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منٹ پہلے اپ ڈیٹ ہوا',
      one: '1 منٹ پہلے اپ ڈیٹ ہوا',
      zero: 'ابھی اپ ڈیٹ ہوا',
    );
    return '$_temp0';
  }

  @override
  String updatedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count گھنٹے پہلے اپ ڈیٹ ہوا',
      one: '1 گھنٹہ پہلے اپ ڈیٹ ہوا',
    );
    return '$_temp0';
  }

  @override
  String updatedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن پہلے اپ ڈیٹ ہوا',
      one: 'کل اپ ڈیٹ ہوا',
    );
    return '$_temp0';
  }

  @override
  String verifiedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منٹ پہلے تصدیق ہوئی',
      one: '1 منٹ پہلے تصدیق ہوئی',
      zero: 'ابھی تصدیق ہوئی',
    );
    return '$_temp0';
  }

  @override
  String verifiedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count گھنٹے پہلے تصدیق ہوئی',
      one: '1 گھنٹہ پہلے تصدیق ہوئی',
    );
    return '$_temp0';
  }

  @override
  String verifiedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن پہلے تصدیق ہوئی',
      one: 'کل تصدیق ہوئی',
    );
    return '$_temp0';
  }

  @override
  String endsInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count گھنٹوں میں ختم',
      one: '1 گھنٹے میں ختم',
    );
    return '$_temp0';
  }

  @override
  String endsInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن میں ختم',
      one: 'کل ختم',
    );
    return '$_temp0';
  }

  @override
  String get endsToday => 'آج ختم';

  @override
  String endsOn(String date) {
    return '$date کو ختم';
  }

  @override
  String get dealOngoing => 'جاری ہے';

  @override
  String get dealExpired => 'ختم ہو گئی';

  @override
  String get featuredLabel => 'نمایاں';

  @override
  String discountBadge(int percent) {
    return '⁦-$percent%⁩';
  }

  @override
  String flatPercentOff(int percent) {
    return 'فلیٹ ⁦$percent%⁩ رعایت';
  }

  @override
  String upToPercentOff(int percent) {
    return '⁦$percent%⁩ تک رعایت';
  }

  @override
  String priceRupees(String amount) {
    return '$amount روپے';
  }

  @override
  String priceWasNow(String oldPrice, String newPrice) {
    return 'پہلے $oldPrice، اب $newPrice';
  }

  @override
  String get allPakistan => 'پورا پاکستان';

  @override
  String get online => 'آن لائن';

  @override
  String get emptyNearby =>
      'بازار آج ٹھنڈا ہے۔ ابھی آس پاس کوئی سیل نہیں، جیسے ہی لگی ہم بتا دیں گے۔';

  @override
  String get emptySaved =>
      'ابھی کچھ محفوظ نہیں۔ کسی ڈیل پر بُک مارک دبائیں، وہ یہاں آ جائے گی۔';

  @override
  String get emptyAlerts =>
      'کسی برانڈ کو فالو کریں، سیل لگتے ہی ہم بتا دیں گے۔';

  @override
  String emptySearch(String query) {
    return '“⁨$query⁩” کے لیے کوئی ڈیل نہیں ملی۔ کوئی اور لفظ آزمائیں یا فلٹر ہٹائیں۔';
  }

  @override
  String get locationOff =>
      'قریب کی ڈیلز دیکھنے کے لیے لوکیشن کی اجازت دیں، یا اپنا علاقہ چنیں۔';

  @override
  String get errorOffline =>
      'انٹرنیٹ کنکشن نہیں ہے۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get errorTimeout =>
      'بہت دیر لگ گئی۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get errorServer =>
      'ہماری طرف سے کوئی مسئلہ ہے۔ ایک منٹ بعد دوبارہ کوشش کریں۔';

  @override
  String get errorUnauthorized =>
      'آپ کا سیشن ختم ہو گیا ہے۔ براہ کرم دوبارہ سائن ان کریں۔';

  @override
  String get errorForbidden => 'آپ کو اس تک رسائی حاصل نہیں۔';

  @override
  String get errorNotFound => 'یہ نہیں ملا۔ شاید یہ ختم ہو چکا ہے۔';

  @override
  String get errorValidation =>
      'کچھ معلومات درست کرنی ہیں۔ نمایاں خانے دیکھیں۔';

  @override
  String get errorRateLimited =>
      'بہت زیادہ کوششیں ہو گئیں۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get errorStorage =>
      'فون میں محفوظ نہیں ہو سکا۔ کچھ جگہ خالی کر کے دوبارہ کوشش کریں۔';

  @override
  String get errorUnexpected => 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get dealTitle => 'ڈیل';

  @override
  String get brandTitle => 'برانڈ';

  @override
  String get categoryTitle => 'کیٹیگری';

  @override
  String get comingSoon => 'جلد آ رہا ہے';

  @override
  String get notFoundTitle => 'صفحہ نہیں ملا';

  @override
  String get notFoundBody =>
      'یہ لنک کہیں نہیں جاتا۔ شاید یہ پرانا ہے یا غلط لکھا گیا ہے۔';

  @override
  String get actionGoHome => 'ہوم پر جائیں';

  @override
  String get exploreHint => 'برانڈز، کھانے اور کارڈ ڈیلز تلاش کریں';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get themeSystem => 'فون کے مطابق';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'گہرا';

  @override
  String get actionContinue => 'آگے چلیں';

  @override
  String get actionSkip => 'چھوڑیں';

  @override
  String get actionBack => 'واپس';

  @override
  String onboardingStep(int step, int total) {
    return 'مرحلہ ⁦$step⁩ از ⁦$total⁩';
  }

  @override
  String get welcomeTitle => 'پاکستان کی ہر سیل، ایک ہی جگہ۔';

  @override
  String get welcomeLanguagePrompt => 'اپنی زبان منتخب کریں';

  @override
  String get welcomeLanguagePromptOther => 'Choose your language';

  @override
  String get cityTitle => 'آپ کہاں شاپنگ کرتے ہیں؟';

  @override
  String get cityBody =>
      'ہم آپ کے شہر کی ڈیلز دکھائیں گے۔ ملک بھر اور آن لائن ڈیلز ہر جگہ نظر آتی ہیں۔';

  @override
  String get actionDetectCity => 'میرا شہر معلوم کریں';

  @override
  String get cityDetecting => 'آپ کا شہر ڈھونڈ رہے ہیں…';

  @override
  String cityDetected(String city) {
    return 'آپ ⁨$city⁩ میں ہیں۔';
  }

  @override
  String get cityNotCovered =>
      'آپ کا مقام ابھی ہمارے کسی شہر کے قریب نہیں۔ نیچے سے شہر چنیں۔';

  @override
  String get cityLocationDenied => 'کوئی بات نہیں۔ نیچے سے اپنا شہر چنیں۔';

  @override
  String get cityLocationBlocked =>
      'اس ایپ کے لیے لوکیشن بند ہے۔ سیٹنگز میں آن کریں یا نیچے سے اپنا شہر چنیں۔';

  @override
  String get cityLocationOff =>
      'آپ کے فون کی لوکیشن بند ہے۔ نیچے سے اپنا شہر چنیں۔';

  @override
  String get cityLocationUnavailable =>
      'ہم آپ کا مقام معلوم نہیں کر سکے۔ نیچے سے اپنا شہر چنیں۔';

  @override
  String get cityLocalSoon => 'مقامی ڈیلز جلد آ رہی ہیں';

  @override
  String get interestsTitle => 'آپ کو کیا پسند ہے؟';

  @override
  String get interestsBody =>
      'اپنی فیڈ کے لیے کم از کم تین چنیں۔ آپ بعد میں بدل سکتے ہیں۔';

  @override
  String interestsPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁦$count⁩ چنے',
      one: 'ایک چنا',
      zero: 'ابھی کوئی نہیں چنا',
    );
    return '$_temp0';
  }

  @override
  String get brandsTitle => 'پسندیدہ برانڈز';

  @override
  String get brandsBody =>
      'برانڈز کو فالو کریں تاکہ ان کی سیل کی خبر سب سے پہلے آپ کو ملے۔';

  @override
  String get brandsEmpty =>
      'یہاں ابھی کوئی برانڈ نہیں۔ آپ بعد میں ایکسپلور سے برانڈز فالو کر سکتے ہیں۔';

  @override
  String brandsFollowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁦$count⁩ برانڈز فالو کیے',
      one: 'ایک برانڈ فالو کیا',
      zero: 'ابھی کسی کو فالو نہیں کیا',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'سب سے پہلے جانیں';

  @override
  String get alertsBody =>
      'جب آپ کا فالو کیا ہوا برانڈ سیل شروع کرے تو الرٹ پائیں۔';

  @override
  String get alertsExampleLabel => 'مثالی الرٹ';

  @override
  String get alertsExampleTitle => 'تھریڈز: ⁦50%⁩ تک رعایت';

  @override
  String get alertsExampleBody => 'ونٹر کلیکشن سیل، اتوار تک';

  @override
  String get alertsPromiseCap => 'دن میں زیادہ سے زیادہ تین الرٹس';

  @override
  String get alertsPromiseQuiet => 'رات کو کبھی نہیں (رات 10 سے صبح 8 بجے تک)';

  @override
  String get alertsPromiseTopics => 'سیٹنگز میں چنیں کہ کن چیزوں کے الرٹس آئیں';

  @override
  String get alertsBlocked =>
      'اس ایپ کے الرٹس بند ہیں۔ آپ انہیں سیٹنگز میں آن کر سکتے ہیں۔';

  @override
  String get signInTitle => 'سنک کے لیے سائن اِن کریں';

  @override
  String get signInBody =>
      'اپنی محفوظ ڈیلز اور فالو کیے برانڈز ہر فون پر رکھیں۔ پاس ورڈ نہیں: ہم آپ کو کوڈ بھیجیں گے۔';

  @override
  String get reauthTitle => 'تصدیق کریں کہ یہ آپ ہیں';

  @override
  String get reauthBody =>
      'آپ کی حفاظت کے لیے، اکاؤنٹ ڈیلیٹ کرنے سے پہلے دوبارہ سائن اِن کریں۔';

  @override
  String get reauthOtherNumber =>
      'تصدیق کے لیے اسی اکاؤنٹ کا نمبر استعمال کریں۔';

  @override
  String get reauthWrongAccount =>
      'یہ کوئی اور اکاؤنٹ ہے، اس لیے کچھ ڈیلیٹ نہیں ہوا۔ آپ سائن آؤٹ ہو گئے ہیں۔';

  @override
  String get phoneLabel => 'موبائل نمبر';

  @override
  String get phoneHint => 'مثلاً ⁦0300 1234567⁩';

  @override
  String get phoneInvalid =>
      'پاکستانی موبائل نمبر درج کریں، جیسے ⁦0300 1234567⁩۔';

  @override
  String get actionSendCode => 'کوڈ بھیجیں';

  @override
  String get signInOr => 'یا';

  @override
  String get actionContinueWithGoogle => 'گوگل کے ساتھ جاری رکھیں';

  @override
  String get codeTitle => 'کوڈ درج کریں';

  @override
  String codeSentTo(String phone) {
    return 'ہم نے ⁦$phone⁩ پر چھ ہندسوں کا کوڈ بھیجا ہے۔';
  }

  @override
  String get codeLabel => 'چھ ہندسوں کا کوڈ';

  @override
  String get codeInvalid =>
      'یہ کوڈ غلط ہے یا اس کی میعاد ختم ہو گئی ہے۔ دوبارہ دیکھیں یا نیا کوڈ منگوائیں۔';

  @override
  String resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'نیا کوڈ ⁦$seconds⁩ سیکنڈ میں',
      one: 'نیا کوڈ ایک سیکنڈ میں',
    );
    return '$_temp0';
  }

  @override
  String get actionResendCode => 'نیا کوڈ بھیجیں';

  @override
  String get actionChangeNumber => 'نمبر بدلیں';

  @override
  String get signInTerms =>
      'جاری رکھ کر آپ ہماری شرائط اور پرائیویسی پالیسی سے اتفاق کرتے ہیں۔';

  @override
  String get signedInToast => 'آپ سائن اِن ہو گئے ہیں۔';

  @override
  String get profileGuestTitle =>
      'اپنی محفوظ ڈیلز ہر فون پر رکھنے کے لیے سائن اِن کریں';

  @override
  String get actionSignIn => 'سائن اِن';

  @override
  String get profileSignedInPhone => 'آپ فون نمبر سے سائن اِن ہیں';

  @override
  String get profileSignedInGoogle => 'آپ گوگل سے سائن اِن ہیں';

  @override
  String get actionSignOut => 'سائن آؤٹ';

  @override
  String get signedOutToast =>
      'سائن آؤٹ ہو گئے۔ سائن اِن کرنے پر آپ کی محفوظ ڈیلز، کارڈز اور فالوز واپس آ جائیں گے۔';

  @override
  String get settingsAccount => 'اکاؤنٹ';

  @override
  String get actionDeleteAccount => 'اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deleteTitle => 'اپنا اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deleteIntro =>
      'اس سے آپ کا اکاؤنٹ اور اس میں موجود سب کچھ ڈیلیٹ ہو جائے گا۔ یہ واپس نہیں ہو سکتا۔';

  @override
  String get deleteListTitle => 'کیا ڈیلیٹ ہوگا';

  @override
  String get deleteItemProfile => 'آپ کی پروفائل اور سائن اِن';

  @override
  String get deleteItemSaves => 'محفوظ ڈیلز، فالو کیے برانڈز اور آپ کے کارڈز';

  @override
  String get deleteItemAlerts => 'الرٹس، نوٹیفکیشنز اور آپ کے فون';

  @override
  String get deleteItemPhotos => 'آپ کی پروفائل تصویر اور بھیجی گئی تصاویر';

  @override
  String get deleteKept =>
      'آپ کی بھیجی ہوئی ڈیلز آپ کے نام کے بغیر برقرار رہیں گی۔ کاروبار اپنے صفحات رکھیں گے۔';

  @override
  String get actionDeleteForever => 'میرا اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deleteConfirmTitle => 'اپنا اکاؤنٹ ڈیلیٹ کریں؟';

  @override
  String get deleteConfirmBody =>
      'آپ سائن آؤٹ ہو جائیں گے، اور یہ فون نئے سرے سے شروع ہوگا۔';

  @override
  String get deletedToast => 'آپ کا اکاؤنٹ ڈیلیٹ ہو گیا۔';

  @override
  String get homeFeaturedTitle => 'نمایاں';

  @override
  String get homeTrendingTitle => 'آج کی مقبول ڈیلز';

  @override
  String get homeNearTitle => 'آپ کے قریب';

  @override
  String get homeEndingTitle => 'جلد ختم ہونے والی';

  @override
  String get homeForYouTitle => 'آپ کے لیے';

  @override
  String get homeNearBody =>
      'اپنے قریب کی سیلز دیکھیں۔ ہم آپ کا مقام صرف ایک بار استعمال کرتے ہیں اور محفوظ نہیں رکھتے۔';

  @override
  String get actionShowNearby => 'میرے قریب کی ڈیلز دکھائیں';

  @override
  String get homeNearLocating => 'آپ کے قریب کی ڈیلز ڈھونڈ رہے ہیں…';

  @override
  String get homeNearNoLocation =>
      'ہم آپ کا مقام معلوم نہیں کر سکے۔ مقامی ڈیلز کے لیے اپنا شہر چنیں۔';

  @override
  String get homeNearBlocked =>
      'اس ایپ کے لیے لوکیشن بند ہے۔ سیٹنگز میں آن کریں یا اپنا شہر چنیں۔';

  @override
  String get homeFeedEnd => 'آپ نے تمام نئی ڈیلز دیکھ لیں۔ جلد دوبارہ دیکھیں۔';

  @override
  String get homeFeedEmpty =>
      'یہاں ابھی کوئی ڈیل نہیں۔ مزید دلچسپیاں یا کوئی اور شہر چنیں۔';

  @override
  String get actionChangeCity => 'شہر بدلیں';

  @override
  String homeCityLabel(String city) {
    return '⁨$city⁩ کی ڈیلز';
  }

  @override
  String distanceMeters(String meters) {
    return '⁦$meters⁩ میٹر';
  }

  @override
  String distanceKm(String km) {
    return '⁦$km⁩ کلومیٹر';
  }

  @override
  String get dealEndedBanner =>
      'یہ ڈیل ختم ہو چکی ہے۔ اسے یہاں رکھا گیا ہے تاکہ اس کے لنک کام کرتے رہیں۔';

  @override
  String dealStartsOn(String date) {
    return '⁨$date⁩ سے شروع';
  }

  @override
  String get dealPromoCode => 'پرومو کوڈ';

  @override
  String get actionCopyCode => 'کوڈ کاپی کریں';

  @override
  String get codeCopiedToast => 'کوڈ کاپی ہو گیا۔';

  @override
  String get dealAbout => 'اس ڈیل کے بارے میں';

  @override
  String get dealTerms => 'شرائط';

  @override
  String get dealWhere => 'کہاں استعمال کریں';

  @override
  String get dealOnlineOnly =>
      'صرف آن لائن: برانڈ کی ویب سائٹ یا ایپ پر استعمال کریں۔';

  @override
  String get dealEverywhere => 'پورے پاکستان میں برانڈ کی دکانوں پر۔';

  @override
  String get dealNoOutlets => 'اپنی قریبی دکان پر پوچھیں۔';

  @override
  String get dealOfflineDetails =>
      'تفصیل، شرائط اور دکانیں انٹرنیٹ واپس آنے پر نظر آئیں گی۔';

  @override
  String get actionDirections => 'راستہ';

  @override
  String get actionCall => 'کال کریں';

  @override
  String get actionSeeSource => 'ماخذ دیکھیں';

  @override
  String get actionOpenOffer => 'آفر کھولیں';

  @override
  String get dealCards => 'ان کارڈز کے ساتھ';

  @override
  String get actionReportProblem => 'مسئلہ بتائیں';

  @override
  String get reportTitle => 'اس ڈیل میں کیا غلط ہے؟';

  @override
  String get reportExpired => 'یہ ختم ہو گئی ہے';

  @override
  String get reportWrongPrice => 'قیمت یا رعایت غلط ہے';

  @override
  String get reportWrongPlace => 'یہ اس جگہ پر نہیں ہے';

  @override
  String get reportClosed => 'دکان بند ہے';

  @override
  String get reportSpam => 'یہ اسپام یا جعلی ہے';

  @override
  String get reportOffensive => 'یہ نامناسب ہے';

  @override
  String get reportOther => 'کچھ اور';

  @override
  String get reportNoteLabel => 'مزید بتائیں (اختیاری)';

  @override
  String get reportNoteRequired => 'براہ کرم بتائیں کہ کیا غلط ہے۔';

  @override
  String get actionSend => 'بھیجیں';

  @override
  String get reportThanks => 'شکریہ۔ ہم اسے دیکھیں گے۔';

  @override
  String get reportAlready => 'آپ یہ ڈیل پہلے ہی رپورٹ کر چکے ہیں۔ شکریہ!';

  @override
  String get reportSignIn =>
      'ڈیل رپورٹ کرنے کے لیے سائن اِن کریں، تاکہ جعلی رپورٹس روکی جا سکیں۔';

  @override
  String shareDealText(String brand, String offer, String title) {
    return '⁨$brand⁩: ⁨$offer⁩۔ ⁨$title⁩۔ سیل لگی ہے! پر ملی';
  }

  @override
  String get savedToast => 'محفوظ ہو گئی۔';

  @override
  String get unsavedToast => 'محفوظ سے ہٹا دی گئی۔';

  @override
  String get linkFailed => 'یہ نہیں کھل سکا۔ بعد میں دوبارہ کوشش کریں۔';

  @override
  String get exploreCategories => 'کیٹیگریز';

  @override
  String get exploreBrands => 'برانڈز';

  @override
  String get categoryAll => 'سب';

  @override
  String get brandVerified => 'تصدیق شدہ برانڈ';

  @override
  String get actionVisitWebsite => 'ویب سائٹ دیکھیں';

  @override
  String get brandNoDeals =>
      'اس برانڈ کی ابھی کوئی ڈیل نہیں۔ فالو کریں تاکہ اگلی سیل کی خبر ملے۔';

  @override
  String get categoryNoDeals =>
      'یہاں ابھی کوئی ڈیل نہیں۔ فالو کریں تاکہ نئی ڈیل کی خبر ملے۔';

  @override
  String followedToast(String name) {
    return '⁨$name⁩ کو فالو کر لیا۔ سیل شروع ہوتے ہی ہم بتائیں گے۔';
  }

  @override
  String unfollowedToast(String name) {
    return '⁨$name⁩ کو فالو کرنا بند کر دیا۔';
  }

  @override
  String followLabel(String name) {
    return '⁨$name⁩ کو فالو کریں';
  }

  @override
  String get listEnd => 'یہاں کی تمام ڈیلز یہی ہیں۔';

  @override
  String get searchTitle => 'تلاش';

  @override
  String get searchFieldLabel => 'ڈیلز تلاش کریں';

  @override
  String get actionClearSearch => 'تلاش صاف کریں';

  @override
  String get searchRecent => 'حالیہ تلاش';

  @override
  String get actionClearRecent => 'سب صاف کریں';

  @override
  String actionRemoveRecent(String query) {
    return '“⁨$query⁩” ہٹائیں';
  }

  @override
  String get searchRecentPrivacy => 'حالیہ تلاش صرف اسی فون پر رہتی ہے۔';

  @override
  String get searchPopular => 'مقبول زمرے';

  @override
  String get searchSuggestions => 'تجاویز';

  @override
  String get searchKindBrand => 'برانڈ';

  @override
  String get searchKindCategory => 'زمرہ';

  @override
  String get searchKindArea => 'علاقہ: یہاں کی ڈیلز دیکھیں';

  @override
  String get searchDeals => 'ڈیلز';

  @override
  String get searchNoFilterResults =>
      'ان فلٹرز کے مطابق کوئی ڈیل نہیں۔ کم فلٹر آزمائیں۔';

  @override
  String get filtersTitle => 'فلٹرز';

  @override
  String filtersOn(int count) {
    return 'فلٹرز (⁦$count⁩)';
  }

  @override
  String get filterArea => 'علاقہ';

  @override
  String get filterAnyArea => 'کہیں بھی';

  @override
  String get filterAreaNeedsCity =>
      'علاقے کا فلٹر لگانے کے لیے ہوم پر شہر منتخب کریں۔';

  @override
  String get filterCategory => 'زمرہ';

  @override
  String get filterBank => 'ان بینکوں کی کارڈ آفرز';

  @override
  String get filterDiscount => 'رعایت';

  @override
  String get filterAnyDiscount => 'کوئی بھی';

  @override
  String filterMinPercent(String percent) {
    return '⁦$percent%+⁩ رعایت';
  }

  @override
  String get filterEndingSoon => 'جلد ختم ہونے والی';

  @override
  String get filterEndingSoonHint => 'تین دن کے اندر ختم';

  @override
  String get actionShowDeals => 'ڈیلز دکھائیں';

  @override
  String get myCardsTitle => 'میرے کارڈز';

  @override
  String get myCardsPrivacy =>
      'ہم کبھی کارڈ نمبر نہیں مانگتے: صرف آپ کا بینک اور کارڈ کی قسم۔ آپ کے کارڈز اسی فون پر رہتے ہیں، اور سائن اِن کریں تو آپ کے اکاؤنٹ میں بھی۔';

  @override
  String get myCardsYours => 'آپ کے کارڈز';

  @override
  String get myCardsEmpty =>
      'اپنے کارڈز شامل کریں اور دیکھیں ان پر کون سی رعایتیں ملتی ہیں۔';

  @override
  String get myCardsDeals => 'آپ کے کارڈز کی آفرز';

  @override
  String get myCardsNoDeals =>
      'ابھی آپ کے کارڈز کی کوئی آفر نہیں۔ شروع ہوتے ہی یہاں نظر آئیں گی۔';

  @override
  String myCardsFull(int count) {
    return 'آپ زیادہ سے زیادہ ⁦$count⁩ کارڈز شامل کر سکتے ہیں۔ نیا شامل کرنے کے لیے کوئی ایک ہٹائیں۔';
  }

  @override
  String get myCardsEntry => 'میرے کارڈز: اپنے کارڈز کی رعایتیں دیکھیں';

  @override
  String get actionAddCard => 'کارڈ شامل کریں';

  @override
  String actionRemoveCard(String card) {
    return '⁨$card⁩ ہٹائیں';
  }

  @override
  String get addCardPickBank => 'کون سا بینک؟';

  @override
  String addCardPickType(String bank) {
    return '⁨$bank⁩ کا کون سا کارڈ؟';
  }

  @override
  String get cardAlreadyAdded => 'پہلے سے شامل ہے';

  @override
  String cardAddedToast(String card) {
    return '⁨$card⁩ شامل ہو گیا';
  }

  @override
  String cardRemovedToast(String card) {
    return '⁨$card⁩ ہٹا دیا گیا';
  }

  @override
  String cardName(String bank, String product, String kind) {
    return '⁨$bank⁩ کا ⁨$product⁩ (⁨$kind⁩)';
  }

  @override
  String get cardKindCredit => 'کریڈٹ';

  @override
  String get cardKindDebit => 'ڈیبٹ';

  @override
  String get cardKindPrepaid => 'پری پیڈ';

  @override
  String emptySearchNoFilters(String query) {
    return '“⁨$query⁩” کے لیے کوئی ڈیل نہیں ملی۔ کوئی اور لفظ آزمائیں۔';
  }

  @override
  String savedActive(int count) {
    return 'جاری (⁦$count⁩)';
  }

  @override
  String savedEnded(int count) {
    return 'ختم (⁦$count⁩)';
  }

  @override
  String get savedNoEnded => 'آپ کی محفوظ کردہ کوئی ڈیل ختم نہیں ہوئی۔';

  @override
  String get savedNoActive => 'آپ کی محفوظ کردہ کوئی ڈیل اس وقت جاری نہیں۔';

  @override
  String savedGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁦$count⁩ محفوظ ڈیلز اب دستیاب نہیں۔',
      one: 'ایک محفوظ ڈیل اب دستیاب نہیں۔',
    );
    return '$_temp0';
  }

  @override
  String get actionRemoveThem => 'انہیں ہٹائیں';

  @override
  String get actionRemoveEnded => 'ختم شدہ ڈیلز ہٹائیں';

  @override
  String get actionUndo => 'واپس لیں';

  @override
  String get alertJustNow => 'ابھی ابھی';

  @override
  String alertMinutesAgo(int count) {
    return '⁦$count⁩ منٹ پہلے';
  }

  @override
  String alertHoursAgo(int count) {
    return '⁦$count⁩ گھنٹے پہلے';
  }

  @override
  String get alertYesterday => 'کل';

  @override
  String get alertUnread => 'نہیں پڑھا';

  @override
  String get alertsToday => 'آج';

  @override
  String get alertsEarlier => 'پہلے';

  @override
  String get actionMarkAllRead => 'سب کو پڑھا ہوا کریں';

  @override
  String get alertsGuest =>
      'یہاں الرٹس پانے کے لیے سائن اِن کریں، ہر اُس فون پر جو آپ استعمال کرتے ہیں۔ فالو کرنا اکاؤنٹ کے بغیر بھی ہوتا ہے۔';

  @override
  String get followingTitle => 'فالو کیے ہوئے';

  @override
  String followingSummary(int brands, int categories) {
    String _temp0 = intl.Intl.pluralLogic(
      brands,
      locale: localeName,
      other: '⁦$brands⁩ برانڈز',
      one: 'ایک برانڈ',
      zero: 'کوئی برانڈ نہیں',
    );
    String _temp1 = intl.Intl.pluralLogic(
      categories,
      locale: localeName,
      other: '⁦$categories⁩ زمرے',
      one: 'ایک زمرہ',
      zero: 'کوئی زمرہ نہیں',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get followingBrands => 'برانڈز';

  @override
  String get followingCategories => 'زمرے';

  @override
  String get followingEmpty =>
      'آپ ابھی کچھ فالو نہیں کر رہے۔ برانڈز اور زمرے فالو کریں تاکہ ان کی ڈیلز کی خبر ملے۔';

  @override
  String get actionExplore => 'برانڈز دیکھیں';

  @override
  String alertsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁦$count⁩ نئے الرٹس',
      one: 'ایک نیا الرٹ',
    );
    return '$_temp0';
  }

  @override
  String get alertsBadgeMany => '⁦99⁩ سے زیادہ نئے الرٹس';

  @override
  String get reportNoteCardNumber =>
      'براہِ کرم کارڈ نمبر نہ لکھیں۔ ہمیں ان کی کبھی ضرورت نہیں ہوتی۔';

  @override
  String get settingsTitle => 'سیٹنگز';

  @override
  String get settingsCity => 'شہر';

  @override
  String get settingsTheme => 'ظاہری انداز';

  @override
  String get settingsNotifications => 'نوٹیفکیشنز';

  @override
  String get settingsPrivacy => 'رازداری';

  @override
  String get settingsLegal => 'قانونی';

  @override
  String get legalTerms => 'استعمال کی شرائط';

  @override
  String get legalPrivacy => 'رازداری کی پالیسی';

  @override
  String get settingsAbout => 'تعارف';

  @override
  String aboutVersion(String version) {
    return 'ورژن ⁦$version⁩';
  }

  @override
  String get aboutLicenses => 'اوپن سورس لائسنس';

  @override
  String get aboutContact => 'ہم سے رابطہ کریں';

  @override
  String get aboutTagline => 'پاکستان کی ہر سیل، ایک جگہ۔';

  @override
  String get notifSignIn =>
      'کون سے الرٹس ملیں، یہ چننے کے لیے سائن اِن کریں۔ فالو کرنا اکاؤنٹ کے بغیر بھی ہوتا ہے۔';

  @override
  String get notifPush => 'پُش نوٹیفکیشنز';

  @override
  String get notifPushHint => 'اس فون پر الرٹس، ان باکس کے ساتھ ساتھ۔';

  @override
  String get notifBlocked =>
      'آپ کے فون کی سیٹنگز میں اس ایپ کے نوٹیفکیشنز بند ہیں۔';

  @override
  String get notifTopics => 'کس بارے میں بتائیں';

  @override
  String get topicBrands => 'فالو کیے ہوئے برانڈز';

  @override
  String get topicCategories => 'فالو کیے ہوئے زمرے';

  @override
  String get topicCards => 'آپ کے کارڈز کی آفرز';

  @override
  String get topicCity => 'آپ کے شہر کی نئی ڈیلز';

  @override
  String get topicPriceDrops => 'محفوظ کردہ ڈیلز کی قیمت میں کمی';

  @override
  String get topicExpiring => 'جلد ختم ہونے والی محفوظ ڈیلز';

  @override
  String get notifFrequency => 'کتنی بار';

  @override
  String get freqLow => 'دن میں زیادہ سے زیادہ ایک';

  @override
  String get freqNormal => 'دن میں زیادہ سے زیادہ تین';

  @override
  String get freqHigh => 'دن میں زیادہ سے زیادہ چھ';

  @override
  String get notifQuiet => 'خاموش اوقات';

  @override
  String quietFrom(String time) {
    return '⁦$time⁩ سے';
  }

  @override
  String quietTo(String time) {
    return '⁦$time⁩ تک';
  }

  @override
  String get quietHint =>
      'ان اوقات میں کوئی پُش نہیں (پاکستان کا وقت)۔ یہ صبح تک انتظار کرتی ہیں۔';

  @override
  String get quietSame => 'خاموش اوقات کا آغاز اور اختتام الگ ہونا چاہیے۔';

  @override
  String get notifSaveFailed => 'یہ محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get notifQueued =>
      'اس فون پر محفوظ ہو گیا۔ انٹرنیٹ واپس آنے پر بھیج دیا جائے گا۔';

  @override
  String get privacyOnPhone => 'اس فون پر';

  @override
  String get privacyOnPhoneBody =>
      'آپ کی زبان، شہر، فالو، محفوظ کردہ ڈیلز، حالیہ تلاش اور کارڈز۔ آپ کا اندازاً مقام صرف \"آپ کے قریب\" کے لیے استعمال ہوتا ہے، اور کبھی محفوظ نہیں ہوتا۔';

  @override
  String get privacyInAccount => 'آپ کے اکاؤنٹ میں';

  @override
  String get privacyInAccountBody =>
      'اگر آپ سائن اِن کریں: یہی پسند، تاکہ دوسرے فون پر بھی ملے، اور آپ کی الرٹ سیٹنگز اور الرٹس۔';

  @override
  String get privacyNever =>
      'کبھی نہیں: کارڈ نمبر، آپ کا درست مقام، یا برانڈز کو بیچا گیا کچھ بھی۔';

  @override
  String get actionClearSearches => 'حالیہ تلاش صاف کریں';

  @override
  String get actionClearCache => 'ڈیلز کی محفوظ کاپیاں صاف کریں';

  @override
  String get actionClearPhone => 'اس فون پر سب کچھ صاف کریں';

  @override
  String get clearPhoneTitle => 'یہ فون صاف کریں؟';

  @override
  String get clearPhoneBody =>
      'اس فون پر آپ کی پسند، فالو، محفوظ کردہ ڈیلز اور کارڈز ہٹ جائیں گے، اور آپ سائن آؤٹ ہو جائیں گے۔ اکاؤنٹ میں موجود سب کچھ رہے گا۔';

  @override
  String get actionClear => 'صاف کریں';

  @override
  String get clearedToast => 'صاف ہو گیا۔';

  @override
  String get adLabel => 'اشتہار';

  @override
  String get sponsoredLabel => 'سپانسرڈ';

  @override
  String sponsorBannerLabel(String sponsor, String title) {
    return '$sponsor کی جانب سے سپانسرڈ: $title';
  }

  @override
  String get privacyAds => 'اشتہارات';

  @override
  String get privacyAdsBody =>
      'ایپ میں گوگل کے اشتہارات دکھائے جاتے ہیں، جو انہیں چننے کے لیے آپ کے فون کی ایڈورٹائزنگ آئی ڈی استعمال کر سکتا ہے۔ آپ یہ آئی ڈی فون کی سیٹنگز میں ری سیٹ یا ڈیلیٹ کر سکتے ہیں۔ سپانسر بینرز صرف آپ کا شہر استعمال کرتے ہیں۔';

  @override
  String get actionAdChoices => 'اشتہارات کے انتخاب';
}
