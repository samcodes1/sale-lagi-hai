-- My Cards (sub-phase 4.7). Shoppers pick their bank and card type, never
-- a card number: a card is only a card_products row ("HBL Visa Platinum
-- Credit"). Guests keep their cards on the phone, so the deals for a set
-- of cards are open to anon; the signed-in "my cards" list is the same
-- rule over the user's own user_cards.

-- Live card offers that one of these cards gets: same bank, and the
-- offer's product, kind and network (where set) match the card. At most
-- 20 cards; unknown or inactive products match nothing.
create function public.deals_for_cards(
  card_product_ids uuid[],
  city_id uuid default null,
  after_published_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker
set search_path = ''
as $$
  with cards as (
    select cp.id, cp.bank_id, cp.kind, cp.network
    from public.card_products cp
    where cp.is_active
      -- The first 20 ids, however the array is shaped (unnest flattens a
      -- 2-D one; QA 4.7-C1).
      and cp.id in (select u.id from unnest(deals_for_cards.card_product_ids) u(id) limit 20)
  )
  select d.*, false, null::integer
  from public.deal_cards d
  where d.kind = 'card_offer'
    and private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, deals_for_cards.city_id)
    and exists (
      select 1
      from public.card_offers co
      join cards cp on co.bank_id = cp.bank_id
      where co.deal_id = d.id
        and (co.card_product_id is null or co.card_product_id = cp.id)
        and (co.card_kind is null or co.card_kind = cp.kind)
        and (co.card_network is null or co.card_network = cp.network))
    and (deals_for_cards.after_published_at is null
         or (d.published_at, d.id) < (deals_for_cards.after_published_at,
              coalesce(deals_for_cards.after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
  order by d.published_at desc, d.id desc
  limit private.page_size(deals_for_cards.page_size);
$$;

-- The signed-in list is now the same rule over the user's own cards.
create or replace function public.deals_for_my_cards(
  city_id uuid default null,
  after_published_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  select * from public.deals_for_cards(
    array(select uc.card_product_id from public.user_cards uc
          where uc.user_id = (select auth.uid())
          order by uc.created_at, uc.card_product_id),
    deals_for_my_cards.city_id, deals_for_my_cards.after_published_at,
    deals_for_my_cards.after_id, deals_for_my_cards.page_size);
$$;

revoke execute on function public.deals_for_cards(uuid[], uuid, timestamptz, uuid, integer) from public;
grant execute on function public.deals_for_cards(uuid[], uuid, timestamptz, uuid, integer)
  to anon, authenticated, service_role;

-- Card products are public reference data, readable like banks.
-- (Their RLS policy is in 20261029130100_rls_policies.sql.)
