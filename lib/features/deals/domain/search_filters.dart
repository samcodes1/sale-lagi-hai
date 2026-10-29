import 'package:meta/meta.dart';

/// The discounts the filter offers: at least this percentage off.
const discountSteps = [10, 25, 50];

/// "Ending soon" in search: ends within this many hours.
const endingSoonHours = 72;

/// What narrows a search besides the words and the city. Empty fields mean
/// "any".
@immutable
final class SearchFilters {
  const new({
    this.areaId,
    this.categoryIds = const [],
    this.bankIds = const [],
    this.minPercent,
    this.endingSoon = false,
  });

  /// Local deals for this area (or its whole city); online and nationwide
  /// deals stay.
  final String? areaId;

  /// Top-level categories; their subcategories are included.
  final List<String> categoryIds;

  /// Card offers of one of these banks.
  final List<String> bankIds;

  /// At least this percentage off (one of [discountSteps]).
  final int? minPercent;

  /// Ends within [endingSoonHours].
  final bool endingSoon;

  static const none = SearchFilters();

  bool get isEmpty => count == 0;

  /// How many filters are on, for the "Filters (2)" button.
  int get count =>
      (areaId != null ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (bankIds.isNotEmpty ? 1 : 0) +
      (minPercent != null ? 1 : 0) +
      (endingSoon ? 1 : 0);

  SearchFilters copyWith({
    String? Function()? areaId,
    List<String>? categoryIds,
    List<String>? bankIds,
    int? Function()? minPercent,
    bool? endingSoon,
  }) => SearchFilters(
    areaId: areaId == null ? this.areaId : areaId(),
    categoryIds: categoryIds ?? this.categoryIds,
    bankIds: bankIds ?? this.bankIds,
    minPercent: minPercent == null ? this.minPercent : minPercent(),
    endingSoon: endingSoon ?? this.endingSoon,
  );

  /// The same filters for another city: areas belong to one city.
  SearchFilters forOtherCity() => copyWith(areaId: () => null);

  static String _key(List<String> ids) => (ids.toList()..sort()).join(',');

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.areaId == areaId &&
      _key(other.categoryIds) == _key(categoryIds) &&
      _key(other.bankIds) == _key(bankIds) &&
      other.minPercent == minPercent &&
      other.endingSoon == endingSoon;

  @override
  int get hashCode => Object.hash(
    areaId,
    _key(categoryIds),
    _key(bankIds),
    minPercent,
    endingSoon,
  );

  // No ids: filters can name places.
  @override
  String toString() => 'SearchFilters($count on)';
}
