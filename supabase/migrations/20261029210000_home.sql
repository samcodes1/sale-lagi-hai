-- Home feed (sub-phase 4.3): the "Ending soon" row. The other home rows
-- use the read APIs of 2.3 (featured, trending, nearby, feed).

-- Live deals that end within `within_hours` (1 to 168, default 72), the
-- soonest first. Shown in a city like the feed: nationwide and online
-- everywhere, local ones in their live target city. Ids are ranked on
-- the deals table (deals_status_ends_idx) and cards built for the page
-- only, through the same RLS joins as deal_cards.
create function public.ending_soon_deals(
  city_id uuid default null,
  within_hours integer default 72,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  with ranked as (
    select d.id, d.ends_at
    from public.deals d
    join public.brands b on b.id = d.brand_id
    join public.categories c on c.id = d.category_id
    where d.status = 'published'
      and d.starts_at <= now()
      and d.ends_at > now()
      and d.ends_at <= now() + make_interval(hours => least(greatest(coalesce(within_hours, 72), 1), 168))
      and (d.scope <> 'local' or (
        exists (select 1 from public.cities ci where ci.id = ending_soon_deals.city_id and ci.is_live)
        and exists (select 1 from public.deal_targets t
                    where t.deal_id = d.id and t.city_id = ending_soon_deals.city_id)))
    order by d.ends_at, d.id
    limit private.page_size(page_size)
  )
  select d.*, false, null::integer
  from ranked r
  join public.deal_cards d on d.id = r.id
  order by r.ends_at, r.id;
$$;
revoke execute on function public.ending_soon_deals(uuid, integer, integer) from public;
grant execute on function public.ending_soon_deals(uuid, integer, integer)
  to anon, authenticated, service_role;
