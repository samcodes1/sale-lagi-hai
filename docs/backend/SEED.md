# Reference and seed data

| What | Where | Runs |
|---|---|---|
| Cities, areas, categories, banks, card products, top brands | Migration `20261029170000_reference_seed.sql` | In every environment, including production. Upserts on natural keys, safe to re-run |
| Demo brands, outlets and deals in Karachi | `supabase/seed.sql` | Local and dev only (`supabase db reset`). Idempotent |

`500_seed.test.sql` checks:
- 16 cities, with only Karachi live;
- centres inside Pakistan and areas within 40 km of their city;
- 13 top categories with icons;
- card products for every bank, and no credit cards for Islamic banks;
- re-running both files twice adds nothing and keeps staff changes such as `is_live`;
- all seven demo deals appear in the Karachi feed.

The reference migration deliberately leaves `is_live` alone on re-runs, because staff switch cities on in the console.

## Demo data
Every demo brand is fictional and marked "(Demo)", so no real business is shown with an offer it didn't make. The demo card offer uses a real bank (HBL) on a fictional restaurant and says "(demo)" in its title.

## To verify before launch (owner or staff)
1. **Card catalogue.** The products are generic: Visa debit and PayPak debit for every bank, and Visa credit for eight conventional banks. Check each bank's real networks (Mastercard, UnionPay) and credit products, then add or deactivate products in the admin console.
2. **Areas.** The centres and radii are approximate. Check them on a map for each city before it goes live.
3. **Brand list and websites.** Confirm the official URLs. Ingestion (Phase 3) uses them as sources.
4. **Urdu names.** Have a native speaker proofread the city, area and category names, as for the app's strings.
