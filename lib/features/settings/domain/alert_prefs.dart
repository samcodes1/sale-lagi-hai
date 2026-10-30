import 'package:meta/meta.dart';

/// public.alert_frequency: how many deal pushes a day at most.
enum AlertFrequency {
  low(1),
  normal(3),
  high(6);

  new(this.perDay);

  final int perDay;

  static AlertFrequency fromWire(Object? value) =>
      values.where((f) => f.name == value).firstOrNull ?? normal;
}

/// What a shopper is alerted about, and when (public.alert_prefs). The
/// push dispatcher enforces the caps and quiet hours server-side.
@immutable
final class AlertPrefs {
  const new({
    this.pushEnabled = false,
    this.frequency = AlertFrequency.normal,
    this.quietStart = const (hour: 22, minute: 0),
    this.quietEnd = const (hour: 8, minute: 0),
    this.timeZone = 'Asia/Karachi',
    this.followedBrands = true,
    this.followedCategories = true,
    this.myCards = true,
    this.myCity = true,
    this.savedPriceDrops = true,
    this.savedExpiring = true,
  });

  /// From an `alert_prefs` row ("22:00:00" times).
  factory fromRow(Map<String, Object?> row) {
    ({int hour, int minute}) time(Object? value, ({int hour, int minute}) or) {
      if (value is! String) return or;
      final parts = value.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      // Postgres `time` allows 24:00; a picker can't (QA 4.9-T1).
      if (hour == null || minute == null || hour > 23 || minute > 59) return or;
      if (hour < 0 || minute < 0) return or;
      return (hour: hour, minute: minute);
    }

    bool flag(String key) => row[key] is! bool || row[key]! as bool;
    const defaults = AlertPrefs();
    return AlertPrefs(
      pushEnabled: row['push_enabled'] == true,
      frequency: AlertFrequency.fromWire(row['frequency']),
      quietStart: time(row['quiet_start'], defaults.quietStart),
      quietEnd: time(row['quiet_end'], defaults.quietEnd),
      timeZone: row['time_zone'] is String
          ? row['time_zone']! as String
          : defaults.timeZone,
      followedBrands: flag('followed_brands'),
      followedCategories: flag('followed_categories'),
      myCards: flag('my_cards'),
      myCity: flag('my_city'),
      savedPriceDrops: flag('saved_price_drops'),
      savedExpiring: flag('saved_expiring'),
    );
  }

  final bool pushEnabled;
  final AlertFrequency frequency;
  final ({int hour, int minute}) quietStart;
  final ({int hour, int minute}) quietEnd;
  final String timeZone;
  final bool followedBrands;
  final bool followedCategories;
  final bool myCards;
  final bool myCity;
  final bool savedPriceDrops;
  final bool savedExpiring;

  /// As an `alert_prefs` row ("22:00" times), as [AlertPrefs.fromRow]
  /// reads it back.
  Map<String, Object?> toRow() => {
    'push_enabled': pushEnabled,
    'frequency': frequency.name,
    'quiet_start': wireTime(quietStart),
    'quiet_end': wireTime(quietEnd),
    'time_zone': timeZone,
    'followed_brands': followedBrands,
    'followed_categories': followedCategories,
    'my_cards': myCards,
    'my_city': myCity,
    'saved_price_drops': savedPriceDrops,
    'saved_expiring': savedExpiring,
  };

  /// "22:00" for the database.
  static String wireTime(({int hour, int minute}) t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  bool operator ==(Object other) =>
      other is AlertPrefs &&
      other.pushEnabled == pushEnabled &&
      other.frequency == frequency &&
      other.quietStart == quietStart &&
      other.quietEnd == quietEnd &&
      other.timeZone == timeZone &&
      other.followedBrands == followedBrands &&
      other.followedCategories == followedCategories &&
      other.myCards == myCards &&
      other.myCity == myCity &&
      other.savedPriceDrops == savedPriceDrops &&
      other.savedExpiring == savedExpiring;

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    frequency,
    quietStart,
    quietEnd,
    timeZone,
    followedBrands,
    followedCategories,
    myCards,
    myCity,
    savedPriceDrops,
    savedExpiring,
  );
}
