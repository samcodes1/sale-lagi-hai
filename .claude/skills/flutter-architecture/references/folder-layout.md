# Folder layout and naming

```
lib/
  main.dart                       # calls bootstrap(); nothing else
  app/
    app.dart                      # MaterialApp.router (material_ui), theme, locale, l10n delegates
    bootstrap.dart                # zones, error handlers, Supabase/Firebase/Sentry init, ProviderScope
    config/                       # AppConfig (from --dart-define-from-file), Flavor, appConfigProvider
    router/
      app_router.dart             # GoRouter provider: refreshListenable, redirect, errorBuilder
      routes.dart                 # @TypedGoRoute tree (part 'routes.g.dart')
      deep_link_service.dart      # app_links → parseLink() → router.go
  core/
    result/                       # result.dart (sealed Result), failure.dart (freezed Failure)
    logging/                      # logger setup, redactor, ProviderObserver
    network/                      # SupabaseGateway interface + impl, error mapper, connectivity hint
    storage/                      # SecureStore wrapper, SecureSessionStorage (LocalStorage)
    cache/                        # drift database, tables, DAOs, outbox
    l10n/                         # ARB files (app_en.arb, app_ur.arb) + generated output dir
    utils/                        # clock, formatters (PKR, dates, Urdu digits), bidi isolate helpers
    push/                         # FCM token registration, notification channels, payload parser
  design_system/
    tokens/                       # brand tokens (generated from design/), spacing, radii, motion
    theme/                        # buildTheme(), DealColors ThemeExtension, typography
    widgets/                      # DealCard, DiscountBadge, FeaturedChip, FreshnessTag, Countdown,
                                  # SkeletonX, EmptyView, ErrorView, OfflineBanner, AppBottomSheet…
    gallery/                      # in-app widget gallery (dev flavor only)
  features/
    <feature>/                    # onboarding, feed, deal, search, brands, cards, alerts, saved,
      data/                       #   profile, account, submissions, reports, business_portal, admin
        dtos/                     # *_dto.dart (freezed + json)
        sources/                  # remote (Supabase RPCs), local (drift DAO)
        <x>_repository_impl.dart
      domain/
        entities/                 # freezed entities, value objects
        <x>_repository.dart       # abstract interface class
        services/                 # pure business rules (e.g. expiry, discount, card matching)
      application/
        <x>_providers.dart        # @riverpod functions/classes (part '*.g.dart')
      presentation/
        <x>_screen.dart
        widgets/
test/                             # mirrors lib/ one-to-one
  helpers/                        # pumpApp(), fakes, fixtures, golden host wrapper
  features/<feature>/{data,domain,application,presentation}/
  goldens/                        # alchemist output (ci/ and platform dirs)
  qa/                             # tests written by the QA agent only
integration_test/
  flows/                          # onboarding_flow_test.dart, deep_link_flow_test.dart …
supabase/
  migrations/                     # timestamped SQL
  tests/                          # pgTAP *_test.sql  (+ sql/ for the plain-SQL harness)
  functions/<name>/index.ts       # Edge Functions (+ tests)
  config.toml                     # verify_jwt per function
env/                              # <flavor>.example.json tracked; real files gitignored
```

## Naming
- Files are `snake_case`, and each is named after the architectural role of its class:
  - `DealRepository` (interface) and `SupabaseDealRepository` (impl);
  - `DealDto` and `Deal` (entity);
  - `FeedNotifier`/`feedProvider` (generated);
  - `DealScreen` and `DealCard`.
- Shared widgets go in `design_system/widgets`, never a folder called `widgets/` at the root. Don't name classes after SDK widgets (Flutter guidance).
- One public class per file, plus its private helpers. Barrel files are allowed only per feature's public API (`features/deal/deal.dart` exporting domain and application), never inside layers.
- Test files mirror the lib path and end in `_test.dart`. Golden test files end in `_golden_test.dart` and are tagged `golden`.

## Feature boundaries
- Features talk to each other through `application` providers or `domain` interfaces. For example, `saved` watches `dealByIdProvider` from `deal`.
- Cross-cutting types (`DealId`, `CitySlug`, `Money`) live in `core/` once a second feature needs them.
- The business portal and admin console reuse `core/` and `design_system/`. Portal-only features live in `features/business_portal` and `features/admin`, each with its own router branch guarded by role redirects. They are built as separate web entrypoints (`lib/main_portal.dart`, `lib/main_admin.dart`) so consumer builds don't ship admin code.
