-- Guest items into the account at sign-in, in one call (QA 4.8 BUG-3):
-- the deals a guest saved and the cards they added on this phone. Only
-- deals the caller can see and active card products are added; ones
-- already in the account are skipped. The client sends these only when
-- the phone's lists are its own or this account's (QA 4.8 BUG-1).
create function public.sync_guest_items(
  deal_ids uuid[] default '{}',
  card_product_ids uuid[] default '{}'
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if coalesce(cardinality(deal_ids), 0) > 500
     or coalesce(cardinality(card_product_ids), 0) > 20 then
    raise exception 'at most 500 deals and 20 cards at once' using errcode = '22023';
  end if;
  insert into public.saves (user_id, deal_id)
  select (select auth.uid()), d.id
  from public.deals d
  where d.id = any(coalesce(sync_guest_items.deal_ids, '{}'))
  on conflict do nothing;
  insert into public.user_cards (user_id, card_product_id)
  select (select auth.uid()), cp.id
  from public.card_products cp
  where cp.is_active
    and cp.id = any(coalesce(sync_guest_items.card_product_ids, '{}'))
  on conflict do nothing;
end $$;
revoke execute on function public.sync_guest_items(uuid[], uuid[]) from public, anon;
grant execute on function public.sync_guest_items(uuid[], uuid[]) to authenticated;
