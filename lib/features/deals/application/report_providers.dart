import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/text/card_numbers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Why a deal is wrong (public.report_reason).
enum ReportReason {
  expired,
  wrongPrice('wrong_price'),
  wrongPlace('wrong_place'),
  closed,
  spam,
  offensive,
  other;

  new([this._wire]);

  final String? _wire;
  String get wire => _wire ?? name;
}

enum ReportOutcome { sent, alreadyReported }

/// Sends a report about a deal (UX flow F5): signed-in shoppers only (RLS),
/// at most 10 an hour (`PT429`, a [RateLimitedFailure]). Reporting the same
/// deal twice is not an error.
final reportDealProvider =
    Provider<
      Future<Result<ReportOutcome>> Function(
        String dealId,
        ReportReason reason, {
        String? note,
      })
    >(
      (ref) =>
          (dealId, reason, {note}) => guard(
            () async {
              final text = note?.trim();
              if (reason == ReportReason.other &&
                  (text == null || text.isEmpty)) {
                throw const ValidationFailure(
                  fieldErrors: {'note': 'required'},
                );
              }
              // Never send a card number; the database refuses one too.
              if (text != null && CardNumbers.containsOne(text)) {
                throw const ValidationFailure(
                  fieldErrors: {'note': 'card_number'},
                );
              }
              try {
                await ref.read(backendGatewayProvider).insert('reports', {
                  'deal_id': dealId,
                  'reason': reason.wire,
                  if (text != null && text.isNotEmpty)
                    // 500 characters as Postgres counts them (code
                    // points), never splitting an emoji (QA 4.4 BUG-5).
                    'note': String.fromCharCodes(text.runes.take(500)),
                });
              } on PostgrestException catch (e) {
                // unique (deal_id, reporter_id)
                if (e.code == '23505') return ReportOutcome.alreadyReported;
                rethrow;
              }
              return ReportOutcome.sent;
            },
            logger: ref.read(loggerProvider),
            mappers: const [backendErrorMapper],
          ),
    );
