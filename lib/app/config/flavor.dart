/// The backend environment the app was built for.
///
/// Selected at build time with `--flavor <name>` (Android/iOS build variant)
/// and `--dart-define-from-file=env/<name>.json` (Dart config).
enum Flavor {
  dev,
  staging,
  prod;

  /// Parses a flavor name, returning `null` when it is not recognised.
  static Flavor? tryParse(String value) {
    for (final flavor in Flavor.values) {
      if (flavor.name == value) return flavor;
    }
    return null;
  }

  bool get isProduction => this == Flavor.prod;
}
