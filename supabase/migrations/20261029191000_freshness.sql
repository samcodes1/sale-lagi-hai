-- Freshness (sub-phase 3.6): dead-link checks, the staleness view and a
-- daily note to admins. Deals are flagged for a human, never removed
-- automatically: a link can be down for an hour, a report can be wrong.

alter table public.deals
  add column link_checked_at timestamptz,
  add column link_failures smallint not null default 0 check (link_failures between 0 and 100);

-- Live deals with a link, least recently checked first (at most daily).
create function private.links_to_check(max_links integer default 100)
returns table (deal_id uuid, url text)
language sql stable security definer set search_path = '' as $$
  select d.id, d.url::text from public.deals d
  where d.status = 'published' and d.url is not null
    and (d.link_checked_at is null or d.link_checked_at < now() - interval '1 day')
  order by d.link_checked_at nulls first
  limit least(greatest(max_links, 1), 500);
$$;

-- outcome: 'ok', 'broken' (404/410) or 'unknown' (network, robots,
-- server error): unknown neither clears nor adds a failure.
create function private.record_link_check(deal uuid, outcome text) returns void
language sql volatile security definer set search_path = '' as $$
  update public.deals set
    link_checked_at = now(),
    link_failures = case outcome when 'ok' then 0
                                 when 'broken' then least(link_failures + 1, 100)
                                 else link_failures end
  where id = deal and outcome in ('ok', 'broken', 'unknown');
$$;

-- What staff should look at: live deals that may no longer be right.
create view public.stale_deals with (security_invoker = true) as
select d.id, d.title_en, b.name::text as brand_name, d.freshness, d.verified_at,
       d.link_failures, d.link_checked_at,
       (select count(*) from public.reports r where r.deal_id = d.id and r.status = 'open') as open_reports,
       array_remove(array[
         case when d.link_failures >= 3 then 'broken_link' end,
         case when d.verified_at is null or d.verified_at < now() - interval '14 days' then 'not_verified' end,
         case when d.freshness < 40 then 'low_freshness' end
       ], null) as reasons
from public.deals d join public.brands b on b.id = d.brand_id
where d.status = 'published'
  -- Operational data: staff only.
  and (select private.is_moderator())
  and (d.link_failures >= 3 or d.freshness < 40
       or d.verified_at is null or d.verified_at < now() - interval '14 days');

grant select on public.stale_deals to authenticated;

-- Once a day: tell each admin how many live deals need a look.
create function private.notify_staleness() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  stale bigint;
  n integer;
begin
  select count(*) into stale from public.deals d
  where d.status = 'published'
    and (d.link_failures >= 3 or d.freshness < 40
         or d.verified_at is null or d.verified_at < now() - interval '14 days');
  if stale = 0 then
    return 0;
  end if;
  insert into public.notifications (user_id, kind, title, body)
  select ur.user_id, 'system', stale || ' deals need checking',
         'Open the staleness view in the console.'
  from public.user_roles ur where ur.role = 'admin';
  get diagnostics n = row_count;
  return n;
end $$;

select cron.schedule('notify-staleness', '7 5 * * *', 'select private.notify_staleness()');
