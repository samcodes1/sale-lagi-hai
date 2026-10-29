# My Cards (sub-phase 4.7)

My Cards (screen S14, `/cards`, opened from Profile and from Explore) is where shoppers say which bank cards they hold, to see the card offers they get.

## A card is a product, never a number
- A card is a `card_products` row: bank, name ("Visa Credit"), network and kind. That is all the app stores: card-product ids, on the phone (`cards.v1`, at most 20) and, when signed in, in `user_cards` (`user_id`, `card_product_id`, `created_at`).
- Neither screen has anywhere to type: no text field at all. A widget test checks this.
- The page says it up front: "We never ask for card numbers: only your bank and card type."
- The database test pins `user_cards` to those three columns, and checks that no table has a card-number, CVV, expiry or account-number column (`840_my_cards.test.sql`).

## The page
- **Your cards:** each as "HBL Visa Credit (Credit)", with a remove button. Empty: "Add your cards to see the discounts they get you." with **Add a card**.
- **Add a card** is a sheet in two steps: the bank, then its card types. Cards already added are marked and not offered again. Back returns to the banks. A 21st card is refused with a message.
- **Offers for your cards:** `PagedDealSlivers` over `CardDeals(cards, city)`, which calls `deals_for_cards`, newest first and keyset-paged.

## Guests and accounts
- Guest-first, like saves and follows. Signed in, each change is mirrored to `user_cards` (with `user_id`); a failed mirror keeps the phone's copy. Cards added as a guest move into the account at sign-in (the guest sync).
- The deals come from the phone's list for everyone: `deals_for_cards` takes card-product ids and is open to anon. `deals_for_my_cards` (signed in) is now the same rule over the user's own `user_cards`, for the alert planner.
- A fresh start (account deleted) forgets the cards. The on-phone list uses `StoredStringList` (see DEAL_PAGE.md).

## Backend (`20261029230000_my_cards.sql`)
- `public.deals_for_cards(card_product_ids, city_id, after_published_at, after_id, page_size)` is security invoker: anon and authenticated may call it.
- `public.deals_for_my_cards` delegates to it.

## Demo backend
Demo card offers name only a bank, so any demo card of that bank gets them. The demo card-product ids are now unique per bank (they used to repeat across banks).

## Tests
- `test/features/cards/my_cards_test.dart`:
  - on the phone: add, duplicate, the 20 limit, remove, mirroring with `user_id`, the guest sync, a fresh start;
  - the deals per card, card products from the catalog;
  - the two-step add, already-added cards, Back, remove;
  - privacy (no text input anywhere);
  - Profile and Explore entries;
  - guidelines and 200% text in en and ur (empty, with a card, picking a card).
- `supabase/tests/database/840_my_cards.test.sql`: matching (any card, kind, product, another bank), inactive products, the 20-card cap, the signed-in list equals the rule over one's own cards, RLS on `user_cards`, the privacy pins.
