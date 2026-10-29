import 'package:meta/meta.dart';

/// What a deal promises, as shown on its badge and headline.
///
/// Percentages are always computed from real data ([DealOffer.fromPrices])
/// or stated by the brand; the UI never invents or rounds one up.
@immutable
sealed class DealOffer {
  const new();

  /// The discount from two verified prices, rounded **down**: Rs 4,999 →
  /// Rs 2,999 is 40%, never "up to 41%". Returns `null` when there is no
  /// real reduction, so no badge or struck price is shown.
  static PercentOff? fromPrices({required int was, required int now}) {
    if (was <= 0 || now < 0 || now >= was) return null;
    final percent = ((was - now) * 100) ~/ was;
    return percent < 1 ? null : PercentOff(percent);
  }
}

/// One item or price: "-40%".
final class PercentOff extends DealOffer {
  const new(this.percent)
    : assert(percent > 0 && percent < 100, 'percent must be 1-99');

  final int percent;

  @override
  bool operator ==(Object other) =>
      other is PercentOff && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;
}

/// A range across items: "Up to 50% off" (the "Up to" is mandatory).
final class UpToPercentOff extends DealOffer {
  const new(this.percent)
    : assert(percent > 0 && percent < 100, 'percent must be 1-99');

  final int percent;

  @override
  bool operator ==(Object other) =>
      other is UpToPercentOff && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;
}

/// The same discount on everything: "Flat 30% off".
final class FlatPercentOff extends DealOffer {
  const new(this.percent)
    : assert(percent > 0 && percent < 100, 'percent must be 1-99');

  final int percent;

  @override
  bool operator ==(Object other) =>
      other is FlatPercentOff && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;
}

/// Offers that are not a percentage: "Buy 1 Get 1", "2 for Rs 999".
/// [label] is already localized by the caller.
final class TextOffer extends DealOffer {
  const new(this.label);

  final String label;

  @override
  bool operator ==(Object other) => other is TextOffer && other.label == label;

  @override
  int get hashCode => label.hashCode;
}
