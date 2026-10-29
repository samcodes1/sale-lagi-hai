# Sale Lagi Hai!

Pakistan's deals app: brand sales, food deals, bank card discounts, telecom bundles and instant alerts. Built with Flutter and Supabase.

## Getting started
1. Install Flutter 3.47.x.
2. Create your local config: `cp env/dev.example.json env/dev.json`
3. Run it:
   ```
   flutter pub get
   flutter run --flavor dev --dart-define-from-file=env/dev.json
   ```

## Flavors
| Flavor | Android app ID | Config file |
|---|---|---|
| dev | `pk.salelagihai.app.dev` | `env/dev.json` |
| staging | `pk.salelagihai.app.stg` | `env/staging.json` |
| prod | `pk.salelagihai.app` | `env/prod.json` |

## Docs
- `docs/DEVELOPMENT_PLAN.md`: full plan, phases and quality gates
- `docs/qa/`: QA reports for each sub-phase
- `design/`: brand identity and assets
- `CLAUDE.md`: rules for working on this codebase
