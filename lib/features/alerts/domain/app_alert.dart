import 'package:meta/meta.dart';

/// public.notification_kind.
enum AlertKind {
  dealAlert('deal_alert'),
  priceDrop('price_drop'),
  expiringSaved('expiring_saved'),
  business('business'),
  system('system');

  new(this.wire);

  final String wire;

  static AlertKind fromWire(Object? value) =>
      values.firstWhere((k) => k.wire == value, orElse: () => AlertKind.system);
}

/// One entry in the Alerts inbox. Short text only: no personal data.
@immutable
final class AppAlert {
  const new({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.dealId,
    this.readAt,
  });

  /// From a `notifications` row; a malformed row is a FormatException.
  factory fromRow(Map<String, Object?> row) {
    T req<T>(String key) => switch (row[key]) {
      final T value => value,
      _ => throw FormatException('notifications.$key is missing or not $T'),
    };
    final readAt = row['read_at'];
    return AppAlert(
      id: req<String>('id'),
      kind: AlertKind.fromWire(row['kind']),
      title: req<String>('title'),
      body: row['body'] is String ? row['body']! as String : null,
      dealId: row['deal_id'] is String ? row['deal_id']! as String : null,
      createdAt: DateTime.parse(req<String>('created_at')),
      readAt: readAt is String ? DateTime.parse(readAt) : null,
    );
  }

  final String id;
  final AlertKind kind;
  final String title;
  final String? body;
  final String? dealId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  AppAlert read(DateTime at) => AppAlert(
    id: id,
    kind: kind,
    title: title,
    body: body,
    dealId: dealId,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );

  // No title or body: they name what the shopper follows.
  @override
  String toString() => 'AppAlert(${kind.wire})';
}
