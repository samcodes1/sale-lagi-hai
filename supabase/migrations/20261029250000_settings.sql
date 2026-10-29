-- Settings (sub-phase 4.9): the shopper's alert preferences. The row is
-- created with the profile; these RPCs read and change the caller's own,
-- through its column grant and RLS (only the listed columns are writable).

-- The caller's alert preferences.
create function public.my_alert_prefs()
returns setof public.alert_prefs
language sql stable security invoker
set search_path = ''
as $$
  select * from public.alert_prefs where user_id = (select auth.uid());
$$;

-- Changes only the fields given (null leaves one as it is) and returns the
-- row. Quiet hours must differ (checked by the table); the time zone is
-- checked by its trigger.
create function public.update_alert_prefs(
  push_enabled boolean default null,
  frequency public.alert_frequency default null,
  quiet_start time default null,
  quiet_end time default null,
  time_zone text default null,
  followed_brands boolean default null,
  followed_categories boolean default null,
  my_cards boolean default null,
  my_city boolean default null,
  saved_price_drops boolean default null,
  saved_expiring boolean default null
) returns setof public.alert_prefs
language sql volatile security invoker
set search_path = ''
as $$
  update public.alert_prefs p set
    push_enabled = coalesce(update_alert_prefs.push_enabled, p.push_enabled),
    frequency = coalesce(update_alert_prefs.frequency, p.frequency),
    quiet_start = coalesce(update_alert_prefs.quiet_start, p.quiet_start),
    quiet_end = coalesce(update_alert_prefs.quiet_end, p.quiet_end),
    time_zone = coalesce(update_alert_prefs.time_zone, p.time_zone),
    followed_brands = coalesce(update_alert_prefs.followed_brands, p.followed_brands),
    followed_categories = coalesce(update_alert_prefs.followed_categories, p.followed_categories),
    my_cards = coalesce(update_alert_prefs.my_cards, p.my_cards),
    my_city = coalesce(update_alert_prefs.my_city, p.my_city),
    saved_price_drops = coalesce(update_alert_prefs.saved_price_drops, p.saved_price_drops),
    saved_expiring = coalesce(update_alert_prefs.saved_expiring, p.saved_expiring)
  where p.user_id = (select auth.uid())
  returning p.*;
$$;

revoke execute on function public.my_alert_prefs(),
  public.update_alert_prefs(boolean, public.alert_frequency, time, time, text, boolean, boolean,
                            boolean, boolean, boolean, boolean)
  from public;
grant execute on function public.my_alert_prefs(),
  public.update_alert_prefs(boolean, public.alert_frequency, time, time, text, boolean, boolean,
                            boolean, boolean, boolean, boolean)
  to authenticated, service_role;
