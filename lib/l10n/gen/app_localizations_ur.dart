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
    return 'فلیٹ $percent% رعایت';
  }

  @override
  String upToPercentOff(int percent) {
    return '$percent% تک رعایت';
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
    return '“$query” کے لیے کوئی ڈیل نہیں ملی۔ کوئی اور لفظ آزمائیں یا فلٹر ہٹائیں۔';
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
  String get themeSystem => 'سسٹم کے مطابق';

  @override
  String get themeLight => 'لائٹ';

  @override
  String get themeDark => 'ڈارک';
}
