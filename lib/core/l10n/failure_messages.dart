import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

/// The message shown to users for a failure. Chosen by type only: a
/// failure's `cause` is technical and may hold personal data, so it is
/// never shown.
extension FailureMessage on AppFailure {
  String message(AppLocalizations l10n) => switch (this) {
    OfflineFailure() => l10n.errorOffline,
    TimeoutFailure() => l10n.errorTimeout,
    ServerFailure() => l10n.errorServer,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ForbiddenFailure() => l10n.errorForbidden,
    NotFoundFailure() => l10n.errorNotFound,
    ValidationFailure() => l10n.errorValidation,
    RateLimitedFailure() => l10n.errorRateLimited,
    StorageFailure() => l10n.errorStorage,
    UnexpectedFailure() => l10n.errorUnexpected,
  };
}
