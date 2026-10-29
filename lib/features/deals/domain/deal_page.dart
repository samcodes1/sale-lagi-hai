import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';

/// Where the next page starts: the last row's sort keys (keyset paging).
@immutable
final class FeedCursor {
  const new({required this.publishedAt, required this.id});

  final DateTime publishedAt;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is FeedCursor && other.publishedAt == publishedAt && other.id == id;

  @override
  int get hashCode => Object.hash(publishedAt, id);
}

@immutable
final class DealPage {
  const new(this.deals, {this.next});

  /// A page built from [deals]: a full page has a next cursor.
  factory of(List<Deal> deals, {required int pageSize}) {
    final last = deals.isEmpty ? null : deals.last;
    final published = last?.publishedAt;
    return DealPage(
      deals,
      next: deals.length >= pageSize && last != null && published != null
          ? FeedCursor(publishedAt: published, id: last.id)
          : null,
    );
  }

  final List<Deal> deals;

  /// Null when this is the last page.
  final FeedCursor? next;
}
