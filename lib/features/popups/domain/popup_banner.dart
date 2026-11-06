import 'package:meta/meta.dart';

/// How often one shopper sees the same pop-up.
enum PopupFrequency {
  once,
  daily,
  everyLaunch;

  static PopupFrequency parse(String value) => switch (value) {
    'once' => once,
    'daily' => daily,
    'every_launch' => everyLaunch,
    _ => throw FormatException('popup_banners.frequency: unknown $value'),
  };
}

/// Where the pop-up's button goes.
sealed class PopupTarget {
  const new();
}

/// An https page, in an in-app browser tab.
final class PopupLink extends PopupTarget {
  const new(this.url);

  final String url;
}

final class PopupDeal extends PopupTarget {
  const new(this.dealId);

  final String dealId;
}

final class PopupBrand extends PopupTarget {
  const new(this.slug);

  final String slug;
}

/// A card staff push over Home when the app opens: an announcement, a big
/// sale or a sponsor's campaign. Managed in the `popup_banners` table.
@immutable
final class PopupBanner {
  const new({
    required this.id,
    required this.titleEn,
    this.titleUr,
    this.bodyEn,
    this.bodyUr,
    this.sponsorName,
    this.imagePath,
    this.actionLabelEn,
    this.actionLabelUr,
    this.target,
    this.cityId,
    this.frequency = PopupFrequency.once,
  });

  final String id;
  final String titleEn;
  final String? titleUr;
  final String? bodyEn;
  final String? bodyUr;

  /// Set for a paid campaign: the card is then labelled as sponsored.
  final String? sponsorName;

  /// Artwork in the deal-images bucket.
  final String? imagePath;

  final String? actionLabelEn;
  final String? actionLabelUr;

  /// Where the button goes; no target, no button.
  final PopupTarget? target;

  /// The only city it shows in; `null` shows it everywhere.
  final String? cityId;
  final PopupFrequency frequency;

  String title({required bool urdu}) => urdu ? titleUr ?? titleEn : titleEn;

  String? body({required bool urdu}) => urdu ? bodyUr ?? bodyEn : bodyEn;

  String? actionLabel({required bool urdu}) =>
      urdu ? actionLabelUr ?? actionLabelEn : actionLabelEn;

  /// Whether a shopper who last saw it at [lastSeen] (or never) should see
  /// it again at [now].
  bool isDue({required DateTime? lastSeen, required DateTime now}) {
    if (lastSeen == null) return true;
    return switch (frequency) {
      PopupFrequency.once => false,
      PopupFrequency.daily => !_sameDay(lastSeen.toLocal(), now.toLocal()),
      PopupFrequency.everyLaunch => true,
    };
  }

  /// Daily means once per calendar day on the phone's clock.
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
