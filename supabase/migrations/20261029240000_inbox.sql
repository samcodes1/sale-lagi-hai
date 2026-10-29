-- Alerts inbox (sub-phase 4.8). The dispatcher writes notifications; the
-- app lists its own through RLS and uses these two RPCs, so marking read
-- touches only read_at and only the caller's rows.

-- Marks the caller's notifications read: these ids, or all of them when
-- null. Already-read ones keep their time. Returns how many changed.
create function public.mark_alerts_read(ids uuid[] default null)
returns integer
language sql volatile security invoker
set search_path = ''
as $$
  with changed as (
    update public.notifications n
    set read_at = now()
    where n.user_id = (select auth.uid())
      and n.read_at is null
      and (ids is null or n.id = any(ids[1:200]))
    returning 1
  )
  select count(*)::integer from changed;
$$;

-- How many of the caller's notifications are unread, created after
-- `since` when given (the badge counts those since the tab was last
-- opened). Capped at 100: the badge shows "99+".
create function public.unread_alert_count(since timestamptz default null)
returns integer
language sql stable security invoker
set search_path = ''
as $$
  select count(*)::integer from (
    select 1 from public.notifications n
    where n.user_id = (select auth.uid())
      and n.read_at is null
      and (since is null or n.created_at > since)
    limit 100
  ) x;
$$;

revoke execute on function public.mark_alerts_read(uuid[]), public.unread_alert_count(timestamptz)
  from public;
grant execute on function public.mark_alerts_read(uuid[]), public.unread_alert_count(timestamptz)
  to authenticated, service_role;
