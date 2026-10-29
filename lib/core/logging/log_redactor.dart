/// Removes personal data and credentials from text before it is logged or
/// sent to crash reporting.
///
/// This is a safety net, not a licence to log personal data: callers should
/// still avoid passing it in the first place. When a pattern is ambiguous it
/// errs towards redacting: an over-redacted log line costs a little
/// debugging time, a leaked phone number cannot be taken back.
final class LogRedactor {
  const new();

  /// Longer text is cut to this many characters before redaction. Logs
  /// should never carry payloads this large, and it keeps redaction fast.
  static const maxLength = 8192;

  // ---------------------------------------------------------------- keys ---

  /// A context key is sensitive when one of its words is in this set.
  /// Keys are split into words: `accessToken` → access, token;
  /// `FCMToken` → fcm, token; `user_phone` → user, phone.
  static const _sensitiveWords = {
    'token',
    'tokens',
    'password',
    'passwd',
    'passcode',
    'pin',
    'secret',
    'otp',
    'auth',
    'authorization',
    'credential',
    'credentials',
    'key',
    'apikey',
    'cookie',
    'session',
    'jwt',
    'bearer',
    'phone',
    'telephone',
    'tel',
    'mobile',
    'cell',
    'msisdn',
    'email',
    'cnic',
    'cvv',
    'pan',
    'lat',
    'lng',
    'lon',
    'latitude',
    'longitude',
    'location',
    'coord',
    'coords',
    'coordinates',
    'position',
    'address',
    'query',
    'refresh',
    'cvc',
    'dob',
    'signature',
  };

  /// …or when the whole key, lower-cased without separators, contains one
  /// of these. Catches compounds written without word breaks (`apikey`,
  /// `phonenumber`) and personal names without hiding `brandName`.
  static const _sensitiveFragments = [
    'token',
    'password',
    'passcode',
    'secret',
    'credential',
    'apikey',
    'phonenumber',
    'cellnumber',
    'mobilenumber',
    'cardnumber',
    'telephone',
    'fullname',
    'firstname',
    'lastname',
    'username',
    'displayname',
    'oauthcode',
    'authcode',
  ];

  static final _wordBoundary = RegExp(
    r'[_\-.\s]+|(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])',
  );

  static bool isSensitiveKey(String key) {
    final words = key.split(_wordBoundary).map((w) => w.toLowerCase());
    if (words.any(_sensitiveWords.contains)) return true;
    final compact = key.toLowerCase().replaceAll(RegExp(r'[_\-.\s]'), '');
    return _sensitiveFragments.any(compact.contains);
  }

  // --------------------------------------------------------------- rules ---

  /// Maps text to one canonical form so a single set of rules covers it:
  /// - Urdu (۰–۹), Arabic-Indic (٠–٩) and fullwidth (０–９) digits, and the
  ///   Arabic decimal and thousands separators, become ASCII;
  /// - invisible characters (zero-width spaces, bidi marks) are removed;
  /// - the URL escapes `%40 %3D %2B %3A` become `@ = + :`.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      switch (rune) {
        case >= 0x06F0 && <= 0x06F9:
          buffer.writeCharCode(0x30 + rune - 0x06F0);
        case >= 0x0660 && <= 0x0669:
          buffer.writeCharCode(0x30 + rune - 0x0660);
        case >= 0xFF10 && <= 0xFF19:
          buffer.writeCharCode(0x30 + rune - 0xFF10);
        case 0x066B:
          buffer.write('.');
        case 0x066C:
          buffer.write(',');
        case 0x200B || 0x200C || 0x200D || 0x200E || 0x200F || 0x2060:
        case 0xFEFF || (>= 0x202A && <= 0x202E) || (>= 0x2066 && <= 0x2069):
          break;
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAllMapped(
      _urlEscape,
      (m) => switch (m[0]!.toUpperCase()) {
        '%40' => '@',
        '%3D' => '=',
        '%2B' => '+',
        _ => ':',
      },
    );
  }

  static final _urlEscape = RegExp('%(?:40|3D|2B|3A)', caseSensitive: false);

  /// Any `key=value`, `key: value`, `"key":"value"` or escaped
  /// `\"key\":\"value\"` pair. The value is hidden when [isSensitiveKey]
  /// says the key is sensitive (`refreshToken`, `X-Api-Key`, `client_secret`,
  /// `userLat`…), and kept otherwise.
  static final _keyValue = RegExp(
    r'''(?<![\w-])([A-Za-z][\w-]{0,63})(\\?["']?\s*[:=]\s*\\?["']?)'''
    r'''([^\s"'\\&,;)}\]]{1,512})''',
  );

  /// OAuth/PKCE codes and tokens in URL query strings and fragments. `code`
  /// alone is not a sensitive key: database error codes (`code: 42501`)
  /// must stay readable.
  static final _urlSecret = RegExp(
    '([?&#](?:code|token|access_token|refresh_token|id_token)=)'
    r'([^&#\s]{1,1024})',
    caseSensitive: false,
  );

  /// Coordinates written with their key: `lat=24.86`, `"lng":67.0`.
  static final _keyedCoordinate = RegExp(
    r'''(?<![\w])(lat|lng|lon|latitude|longitude)(["']?\s*[:=]?\s*)'''
    r'''(-?\d{1,3}(?:\.\d{1,15})?)''',
    caseSensitive: false,
  );

  // Ordered: specific and long patterns run before general and short ones,
  // so a card number is never half-matched as a phone number.
  static final _rules = <(RegExp, String Function(Match))>[
    // JSON Web Tokens (session and legacy Supabase keys).
    (RegExp(r'eyJ[\w-]{1,4096}\.[\w-]{1,8192}\.[\w-]{0,4096}'), (_) => '[jwt]'),
    // Supabase publishable and secret keys.
    (RegExp(r'sb_(?:publishable|secret)_[\w-]{1,512}'), (_) => '[key]'),
    // Anything else that looks like base64-encoded JSON: an unsigned or
    // truncated JWT still carries its payload.
    (RegExp(r'eyJ[\w-]{8,8192}'), (_) => '[jwt]'),
    // FCM registration tokens: "<instance id>:APA91b…".
    (RegExp(r'[\w-]{6,255}:APA91b[\w-]{20,4096}'), (_) => '[fcm-token]'),
    // Authorization headers.
    (
      RegExp(r'\bBearer\s+\S{1,4096}', caseSensitive: false),
      (_) => 'Bearer [token]',
    ),
    (
      RegExp(r'\bBasic\s+[A-Za-z0-9+/=]{4,4096}', caseSensitive: false),
      (_) => 'Basic [token]',
    ),
    // key=value secrets and keyed coordinates.
    (_urlSecret, (m) => '${m[1]}[redacted]'),
    (
      _keyValue,
      (m) => isSensitiveKey(m[1]!) && !_isPlaceholderOrScheme(m[3]!)
          ? '${m[1]}${m[2]}[redacted]'
          : m[0]!,
    ),
    (_keyedCoordinate, (m) => '${m[1]}${m[2]}[location]'),
    // Email addresses. Bounded parts keep this linear; asset names such as
    // icon@2x.png are not addresses.
    (
      RegExp(
        r'[\w.+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63}){0,8}'
        r'\.[A-Za-z]{2,24}\b(?<!\.(?:png|jpe?g|gif|webp|svg|avif|ttf|otf))',
      ),
      (_) => '[email]',
    ),
    // Pakistani CNIC: 12345-1234567-1, or 13 digits starting with a
    // province code (1–7). This also catches 13-digit millisecond
    // timestamps; log ISO times instead.
    (RegExp(r'(?<!\d)\d{5}[ -]\d{7}[ -]\d(?!\d)'), (_) => '[cnic]'),
    (RegExp(r'(?<!\d)[1-7]\d{12}(?!\d)'), (_) => '[cnic]'),
    // Pakistani mobile numbers, international (+92, 0092, 92) and local
    // (03xx), with spaces, dots, hyphens, dashes or brackets between groups.
    (
      RegExp(
        r'(?<!\d)(?:\+|00)?92[\s.\-–—()]{0,3}3\d{2}[\s.\-–—()]{0,3}\d{3}'
        r'[\s.\-–—]{0,3}\d{4}(?!\d)',
      ),
      (_) => '[phone]',
    ),
    (
      RegExp(r'(?<!\d)03\d{2}[\s.\-–—()]{0,3}\d{3}[\s.\-–—]{0,3}\d{4}(?!\d)'),
      (_) => '[phone]',
    ),
    // Without the leading 0, as left by a "+92" prefix field: 30x–34x.
    (RegExp(r'(?<!\d)3[0-4]\d{8}(?!\d)'), (_) => '[phone]'),
    // Card numbers: 13–19 digits with optional single separators, a real
    // card prefix (2–6) and a valid Luhn checksum. Other long numbers (SKUs,
    // IDs) are left alone.
    (
      RegExp(r'(?<!\d)(?<!\d-)\d(?:[ -]?\d){12,18}(?!\d)(?!-\d)'),
      (m) => _isCardNumber(m[0]!) ? '[card]' : m[0]!,
    ),
    // Bare coordinate pairs more precise than ~100 m (3+ decimals), unless
    // they follow a currency marker (Rs 1.299, 2.499).
    (
      RegExp(
        r'(?<!(?:Rs|PKR)\.?\s{0,2})-?\b\d{1,3}\.\d{3,15}'
        r'(?:\s*[,;]\s*|\s+)-?\d{1,3}\.\d{3,15}\b',
      ),
      (_) => '[location]',
    ),
  ];

  /// Values an earlier rule already replaced (`[jwt]`), and auth schemes
  /// whose credential the Bearer/Basic rules already hid.
  static bool _isPlaceholderOrScheme(String value) =>
      value.startsWith('[') ||
      const {'bearer', 'basic'}.contains(value.toLowerCase());

  static bool _isCardNumber(String candidate) {
    final digits = candidate.replaceAll(RegExp('[ -]'), '');
    if (!'23456'.contains(digits[0])) return false;
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      var digit = digits.codeUnitAt(digits.length - 1 - i) - 0x30;
      if (i.isOdd) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  // ----------------------------------------------------------------- api ---

  /// Redacts [text].
  String redact(String text) {
    var result = _normalize(
      text.length > maxLength
          ? '${text.substring(0, maxLength)}…[truncated]'
          : text,
    );
    for (final (pattern, replace) in _rules) {
      result = result.replaceAllMapped(pattern, replace);
    }
    return result;
  }

  /// Redacts every value in [context]. Values under sensitive keys are
  /// hidden entirely, including inside nested maps and lists; everything
  /// else is converted to a string and redacted.
  Map<String, String> redactContext(Map<String, Object?> context) => {
    for (final MapEntry(:key, :value) in context.entries)
      key: isSensitiveKey(key) ? '[redacted]' : redact(describe(_mask(value))),
  };

  /// Nesting deeper than this is elided, which also stops cyclic maps and
  /// lists from recursing forever.
  static const _maxDepth = 6;

  static Object? _mask(Object? value, [int depth = 0]) {
    if (value is! Map && value is! Iterable) return value;
    if (depth >= _maxDepth) return '[…]';
    return switch (value) {
      Map<Object?, Object?>() => {
        for (final MapEntry(:key, :value) in value.entries)
          key: isSensitiveKey('$key') ? '[redacted]' : _mask(value, depth + 1),
      },
      Iterable<Object?>() => [
        for (final item in value.take(50)) _mask(item, depth + 1),
      ],
      _ => value,
    };
  }

  /// `toString()` that never throws, for values from arbitrary code.
  static String describe(Object? value) {
    try {
      return '$value';
    } on Object {
      return '[unprintable ${value.runtimeType}]';
    }
  }
}
