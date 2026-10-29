import 'package:meta/meta.dart';

/// What a shopper chose during onboarding (and later in Settings): their
/// city, interests and favourite brands. Kept on the phone, so the app
/// works without an account; signing in (4.2) syncs it.
///
/// No personal data: ids of public reference rows and flags only. A
/// detected location is never kept, only the city it matched.
@immutable
final class ShopperPreferences {
  const new({
    this.onboarded = false,
    this.cityId,
    this.interestIds = const [],
    this.brandIds = const [],
    this.categoryFollowIds = const [],
    this.alertsAskedAt,
  });

  /// Decodes saved preferences. Anything malformed becomes the default,
  /// field by field: a damaged file never blocks the app.
  factory fromJson(Object? json) {
    if (json is! Map) return const ShopperPreferences();
    List<String> ids(Object? value) => [
      if (value is List)
        for (final id in value)
          if (id is String && id.isNotEmpty) id,
    ];
    final asked = json['alerts_asked_at'];
    return ShopperPreferences(
      onboarded: json['onboarded'] == true,
      cityId: switch (json['city_id']) {
        final String id when id.isNotEmpty => id,
        _ => null,
      },
      interestIds: ids(json['interest_ids']),
      brandIds: ids(json['brand_ids']),
      categoryFollowIds: ids(json['category_follow_ids']),
      alertsAskedAt: asked is String ? DateTime.tryParse(asked) : null,
    );
  }

  /// Onboarding finished (or skipped through): the app opens on Home.
  final bool onboarded;

  /// The chosen city; `null` shows nationwide and online deals only.
  final String? cityId;

  /// Top-level category ids.
  final List<String> interestIds;

  /// Followed brands (onboarding step 4, or Follow on a brand page).
  final List<String> brandIds;

  /// Followed categories (Follow on a category page): alerts, unlike
  /// [interestIds], which only tune the feed.
  final List<String> categoryFollowIds;

  /// When the notification priming screen was shown, so the app never asks
  /// again in a loop.
  final DateTime? alertsAskedAt;

  ShopperPreferences copyWith({
    bool? onboarded,
    String? Function()? cityId,
    List<String>? interestIds,
    List<String>? brandIds,
    List<String>? categoryFollowIds,
    DateTime? alertsAskedAt,
  }) => ShopperPreferences(
    onboarded: onboarded ?? this.onboarded,
    cityId: cityId == null ? this.cityId : cityId(),
    interestIds: interestIds ?? this.interestIds,
    brandIds: brandIds ?? this.brandIds,
    categoryFollowIds: categoryFollowIds ?? this.categoryFollowIds,
    alertsAskedAt: alertsAskedAt ?? this.alertsAskedAt,
  );

  Map<String, Object?> toJson() => {
    'onboarded': onboarded,
    'city_id': cityId,
    'interest_ids': interestIds,
    'brand_ids': brandIds,
    'category_follow_ids': categoryFollowIds,
    'alerts_asked_at': alertsAskedAt?.toUtc().toIso8601String(),
  };

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ShopperPreferences &&
      other.onboarded == onboarded &&
      other.cityId == cityId &&
      _same(other.interestIds, interestIds) &&
      _same(other.brandIds, brandIds) &&
      _same(other.categoryFollowIds, categoryFollowIds) &&
      other.alertsAskedAt == alertsAskedAt;

  @override
  int get hashCode => Object.hash(
    onboarded,
    cityId,
    Object.hashAll(interestIds),
    Object.hashAll(brandIds),
    Object.hashAll(categoryFollowIds),
    alertsAskedAt,
  );

  @override
  String toString() =>
      'ShopperPreferences(onboarded: $onboarded, hasCity: ${cityId != null}, '
      'interests: ${interestIds.length}, brands: ${brandIds.length})';
}
