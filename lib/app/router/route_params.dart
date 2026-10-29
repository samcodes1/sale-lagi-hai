/// Validation for values that arrive in URLs (deep links, notifications,
/// web addresses). Every one is untrusted input: routes check their
/// parameters with these before any lookup, and send anything invalid to
/// Home instead of showing it back to the user.
abstract final class RouteParams {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _slug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  /// Deal and other record IDs are lower-case UUIDs.
  static bool isId(String value) => _uuid.hasMatch(value);

  /// Brand and category slugs: lower-case words joined by single hyphens,
  /// at most 64 characters (`khaadi`, `food-and-dining`).
  static bool isSlug(String value) =>
      value.length <= 64 && _slug.hasMatch(value);
}
