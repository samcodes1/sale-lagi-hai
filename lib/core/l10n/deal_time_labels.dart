import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

/// Human labels for when a deal ends and when it was last verified.
///
/// Rules (flutter-ui-ux skill, deal patterns):
/// - no end date → "Ongoing"; already ended → "Expired";
/// - under 6 hours → "Ends in N hours" (precise when it is urgent);
/// - otherwise by calendar day: today, tomorrow, or "in N days" up to 3;
/// - further out → the date, "Ends 3 Nov".
///
/// All times are compared in the device's local time zone.
final class DealTimeLabels {
  const new(this._l10n, this._format);

  final AppLocalizations _l10n;
  final AppFormatters _format;

  static const _urgentWindow = Duration(hours: 6);
  static const _relativeDays = 3;

  String expiry(DateTime? endsAt, {required DateTime now}) {
    if (endsAt == null) return _l10n.dealOngoing;
    final remaining = endsAt.difference(now);
    if (remaining <= Duration.zero) return _l10n.dealExpired;
    if (remaining < _urgentWindow) {
      // Round up: 90 minutes left reads "Ends in 2 hours", never "0 hours".
      final hours = (remaining.inMinutes / 60).ceil();
      return _l10n.endsInHours(hours);
    }
    final days = _calendarDaysBetween(now, endsAt);
    if (days == 0) return _l10n.endsToday;
    if (days <= _relativeDays) return _l10n.endsInDays(days);
    return _l10n.endsOn(_format.shortDate(endsAt.toLocal()));
  }

  /// "Verified 3 hours ago". A time in the future (clock skew) reads as
  /// "just now".
  String verified(DateTime verifiedAt, {required DateTime now}) {
    final age = now.difference(verifiedAt);
    if (age < const Duration(hours: 1)) {
      return _l10n.verifiedMinutesAgo(age.isNegative ? 0 : age.inMinutes);
    }
    if (age < const Duration(days: 1)) {
      return _l10n.verifiedHoursAgo(age.inHours);
    }
    return _l10n.verifiedDaysAgo(age.inDays);
  }

  /// "Updated 2 hours ago", for cached content shown offline.
  String updated(DateTime updatedAt, {required DateTime now}) {
    final age = now.difference(updatedAt);
    if (age < const Duration(hours: 1)) {
      return _l10n.updatedMinutesAgo(age.isNegative ? 0 : age.inMinutes);
    }
    if (age < const Duration(days: 1)) {
      return _l10n.updatedHoursAgo(age.inHours);
    }
    return _l10n.updatedDaysAgo(age.inDays);
  }

  static int _calendarDaysBetween(DateTime from, DateTime to) {
    final a = from.toLocal();
    final b = to.toLocal();
    // UTC dates avoid daylight-saving gaps when counting whole days.
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }
}
