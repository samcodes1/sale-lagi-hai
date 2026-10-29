import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A city the app covers. Local deals go live city by city ([isLive]);
/// nationwide and online deals show in every city.
@immutable
final class City {
  const new({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameUr,
    required this.isLive,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameUr;
  final bool isLive;
  final double latitude;
  final double longitude;

  String name({required bool urdu}) => urdu ? nameUr : nameEn;

  /// Great-circle distance from this city's centre, in kilometres.
  double distanceKm(double latitude, double longitude) {
    const earthKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(latitude - this.latitude);
    final dLng = rad(longitude - this.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(this.latitude)) *
            math.cos(rad(latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthKm * math.asin(math.min(1, math.sqrt(h)));
  }

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The city whose centre is nearest, if one is within [maxKm] (a location
/// outside every covered city returns `null`).
City? nearestCity(
  List<City> cities,
  double latitude,
  double longitude, {
  double maxKm = 60,
}) {
  City? best;
  var bestKm = double.infinity;
  for (final city in cities) {
    final km = city.distanceKm(latitude, longitude);
    if (km < bestKm) {
      best = city;
      bestKm = km;
    }
  }
  return bestKm <= maxKm ? best : null;
}

/// A deal category. Top-level categories ([parentId] null) are the
/// interests shoppers pick; subcategories belong to one of them.
@immutable
final class Category {
  const new({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameUr,
    required this.icon,
    this.parentId,
  });

  final String id;
  final String slug;
  final String? parentId;
  final String nameEn;
  final String nameUr;

  /// A Material Symbols name ("restaurant"); the app maps it to an icon.
  final String icon;

  bool get isTopLevel => parentId == null;

  String name({required bool urdu}) => urdu ? nameUr : nameEn;

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A brand shoppers can follow.
@immutable
final class Brand {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    required this.categoryId,
    this.nameUr,
    this.logoPath,
    this.website,
    this.isVerified = false,
  });

  final String id;
  final String slug;
  final String name;

  /// The brand's own site (https), for "Visit website".
  final String? website;
  final String? nameUr;
  final String categoryId;
  final String? logoPath;
  final bool isVerified;

  String displayName({required bool urdu}) => urdu ? (nameUr ?? name) : name;

  @override
  bool operator ==(Object other) => other is Brand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A neighbourhood of a city (Clifton, DHA), for the search area filter.
@immutable
final class Area {
  const new({
    required this.id,
    required this.cityId,
    required this.slug,
    required this.nameEn,
    required this.nameUr,
  });

  final String id;
  final String cityId;
  final String slug;
  final String nameEn;
  final String nameUr;

  String name({required bool urdu}) => urdu ? nameUr : nameEn;

  @override
  bool operator ==(Object other) => other is Area && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A bank whose cards have offers (search filter, My Cards).
@immutable
final class Bank {
  const new({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameUr,
    required this.shortName,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameUr;

  /// What chips show: "HBL", "Meezan".
  final String shortName;

  String name({required bool urdu}) => urdu ? nameUr : nameEn;

  @override
  bool operator ==(Object other) => other is Bank && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Card networks (public.card_network). Their names are brands, the same
/// in every language.
enum CardNetwork {
  visa('Visa'),
  mastercard('Mastercard'),
  unionpay('UnionPay'),
  paypak('PayPak'),
  amex('Amex'),
  jcb('JCB');

  new(this.label);

  final String label;

  static CardNetwork? fromWire(Object? value) =>
      values.where((n) => n.name == value).firstOrNull;
}

/// public.card_kind.
enum CardKind {
  credit,
  debit,
  prepaid;

  static CardKind? fromWire(Object? value) =>
      values.where((k) => k.name == value).firstOrNull;
}

/// A kind of card a bank issues ("Visa Platinum Credit"). This is all My
/// Cards ever knows about a shopper's card: never a number.
@immutable
final class CardProduct {
  const new({
    required this.id,
    required this.bankId,
    required this.name,
    required this.network,
    required this.kind,
  });

  final String id;
  final String bankId;
  final String name;
  final CardNetwork network;
  final CardKind kind;

  @override
  bool operator ==(Object other) => other is CardProduct && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Reference data: cities, areas, categories, banks, card products and
/// brands.
abstract interface class CatalogRepository {
  /// Every city, live ones first, then in the backend's order.
  Future<List<City>> cities();

  /// Active categories, top-level and sub, in the backend's order.
  Future<List<Category>> categories();

  /// Active brands, by name. [categoryIds] limits them to those categories
  /// (pass subcategories too: a brand belongs to one subcategory). Pages
  /// with [offset].
  Future<List<Brand>> brands({
    List<String>? categoryIds,
    int limit = 60,
    int offset = 0,
  });

  /// An active brand by its slug, or `null`.
  Future<Brand?> brandBySlug(String slug);

  /// The areas of a city, by English name.
  Future<List<Area>> areas(String cityId);

  /// Active banks, by English name.
  Future<List<Bank>> banks();

  /// Active card products of every bank, by name.
  Future<List<CardProduct>> cardProducts();

  /// Brands for what is being typed (1 to 60 characters): names that start
  /// with it first, then close spellings. At most [limit] (up to 10).
  Future<List<Brand>> suggestBrands(String text, {int limit = 6});
}
