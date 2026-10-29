-- Jobs and the push pipeline (sub-phase 2.5).
--
-- Decisions live here, in SQL, where they are tested: who gets an alert,
-- frequency caps, quiet hours, expiry, freshness and rate limits. The
-- push-dispatcher Edge Function only does I/O: it claims due pushes, sends
-- them through FCM and reports back.
--
-- Pipeline: a deal goes live → private.alert_queue → plan_alerts() (every
-- 2 minutes) writes in-app notifications and private.push_outbox rows →
-- the dispatcher claims due rows, sends, marks them sent, drops dead tokens.

-- ===========================================================================
-- Rate limits: reports and submissions per user. Over the limit the insert
-- fails with SQLSTATE PT429, which PostgREST returns as HTTP 429 (the app
-- maps it to RateLimitedFailure). Users can read their own rows, so the
-- count runs with the caller's own RLS. The server sets created_at: a
-- client-chosen (backdated) time would never count.
-- ===========================================================================
create function private.limit_reports() returns trigger
language plpgsql set search_path = '' as $$
begin
  if private.is_trusted_caller() then
    return new;
  end if;
  new.created_at := now();
  if (
    select count(*) from public.reports r
    where r.reporter_id = (select auth.uid()) and r.created_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'rate_limited' using errcode = 'PT429',
      hint = 'At most 10 reports an hour.';
  end if;
  return new;
end $$;
create trigger reports_rate_limit before insert on public.reports
  for each row execute function private.limit_reports();

create function private.limit_submissions() returns trigger
language plpgsql set search_path = '' as $$
declare
  last_hour bigint;
  last_day bigint;
begin
  if private.is_trusted_caller() then
    return new;
  end if;
  new.created_at := now();
  select count(*) filter (where s.created_at > now() - interval '1 hour'), count(*)
    into last_hour, last_day
  from public.submissions s
  where s.submitter_id = (select auth.uid()) and s.created_at > now() - interval '1 day';
  if last_hour >= 5 or last_day >= 20 then
    raise exception 'rate_limited' using errcode = 'PT429',
      hint = 'At most 5 submissions an hour and 20 a day.';
  end if;
  return new;
end $$;
create trigger submissions_rate_limit before insert on public.submissions
  for each row execute function private.limit_submissions();


-- ===========================================================================
-- Expiry: ended deals become expired, placements start and end on time.
-- ===========================================================================
create function private.expire_deals() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  update public.deals set status = 'expired'
  where status = 'published' and ends_at is not null and ends_at <= now();
  get diagnostics n = row_count;

  update public.placements set status = 'ended'
  where status in ('scheduled', 'active') and ends_at <= now();
  update public.placements set status = 'active'
  where status = 'scheduled' and starts_at <= now() and ends_at > now();
  return n;
end $$;

-- ===========================================================================
-- Freshness (0-100): how much to trust that a deal is still right. Recent
-- verification raises it; open reports lower it. Used by the admin
-- console's staleness view and, later, ranking.
-- ===========================================================================
alter table public.deals
  add column freshness smallint not null default 50 check (freshness between 0 and 100);

create function private.freshness_of(verified_at timestamptz, open_reports bigint)
returns smallint language sql stable set search_path = '' as $$
  select greatest(0, least(100,
    case
      when verified_at is null then 40
      when verified_at > now() - interval '1 day' then 100
      when verified_at > now() - interval '3 days' then 80
      when verified_at > now() - interval '7 days' then 60
      when verified_at > now() - interval '30 days' then 30
      else 10
    end - least(open_reports, 4) * 15))::smallint;
$$;

create function private.refresh_freshness() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  with scored as (
    select d.id, private.freshness_of(d.verified_at, count(r.id)) as score
    from public.deals d
    left join public.reports r on r.deal_id = d.id and r.status = 'open'
    where d.status = 'published'
    group by d.id, d.verified_at
  )
  update public.deals d set freshness = s.score
  from scored s where s.id = d.id and d.freshness is distinct from s.score;
  get diagnostics n = row_count;
  return n;
end $$;

-- ===========================================================================
-- Push tokens: one row per device token. Registering through the RPC moves
-- a token to the signed-in user (a phone that switches accounts). A user
-- keeps their 10 most recently seen devices; older tokens are dropped.
-- ===========================================================================
create table public.push_tokens (
  token text primary key check (length(token) between 20 and 4096),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index push_tokens_user_idx on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;

grant select, delete on public.push_tokens to authenticated;
create policy "push tokens: read own" on public.push_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy "push tokens: remove own" on public.push_tokens
  for delete to authenticated using (user_id = (select auth.uid()));

create function public.register_push_token(token text, platform text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'sign in to register for alerts' using errcode = '42501';
  end if;
  insert into public.push_tokens (token, user_id, platform)
  values (register_push_token.token, (select auth.uid()), register_push_token.platform)
  on conflict on constraint push_tokens_pkey do update
    set user_id = excluded.user_id, platform = excluded.platform, last_seen_at = now();
  delete from public.push_tokens t
  where t.user_id = (select auth.uid())
    and t.token not in (
      select k.token from public.push_tokens k
      where k.user_id = (select auth.uid())
      order by k.last_seen_at desc, k.created_at desc
      limit 10);
end $$;
revoke execute on function public.register_push_token(text, text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;

-- ===========================================================================
-- Alert queue: published deals that still need alerts. A deal alerts its
-- followers once, ever: the row stays (with alerted_at) after its alerts
-- go out, so republishing or editing a live deal never alerts again. A
-- published deal that is not live yet (it starts later, or staff haven't
-- activated its brand) waits in the queue until it is.
-- ===========================================================================
create table private.alert_queue (
  deal_id uuid primary key references public.deals on delete cascade,
  queued_at timestamptz not null default now(),
  -- Set when the planner is done with the row: it alerted (alerted_at is
  -- set too) or the deal was no longer published.
  processed_at timestamptz,
  alerted_at timestamptz,
  check (alerted_at is null or processed_at is not null)
);
create index alert_queue_pending_idx on private.alert_queue (queued_at)
  where processed_at is null;

create function private.queue_alerts() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- A deal dropped before it alerted (taken back to draft) is queued again.
  insert into private.alert_queue as q (deal_id) values (new.id)
  on conflict (deal_id) do update set queued_at = now(), processed_at = null
    where q.alerted_at is null and q.processed_at is not null;
  return null;
end $$;
create trigger deals_queue_alerts after insert or update of status on public.deals
  for each row when (new.status = 'published')
  execute function private.queue_alerts();

-- A preference's time zone must be one Postgres knows: the planner
-- converts with it, and one bad row must not stop a whole run.
create function private.check_time_zone() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform now() at time zone new.time_zone;
  return new;
exception when invalid_parameter_value then
  raise exception 'unknown time zone %', new.time_zone using errcode = '23514';
end $$;
create trigger alert_prefs_time_zone before insert or update of time_zone on public.alert_prefs
  for each row execute function private.check_time_zone();

-- ===========================================================================
-- Push outbox: pushes waiting to go out (now, or after quiet hours).
-- ===========================================================================
create table private.push_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  deal_id uuid references public.deals on delete set null,
  brand_id uuid references public.brands on delete set null,
  -- The day it goes out, in the user's time zone: daily caps count by it.
  local_day date not null,
  title text not null check (length(title) between 1 and 120),
  body text check (length(body) <= 300),
  send_at timestamptz not null,
  claimed_at timestamptz,
  sent_at timestamptz,
  attempts smallint not null default 0,
  created_at timestamptz not null default now()
);
create index push_outbox_due_idx on private.push_outbox (send_at) where sent_at is null;
create index push_outbox_caps_idx on private.push_outbox (user_id, local_day, brand_id);
create index push_outbox_deal_idx on private.push_outbox (deal_id);
create index push_outbox_brand_idx on private.push_outbox (brand_id);

-- The offer as a short headline ("40% off", "Rs 500 off"). Urdu numbers
-- sit in LTR isolates so they read correctly in right-to-left text.
create function private.offer_headline(d public.deals, lang text) returns text
language sql stable set search_path = '' as $$
  select case
    when lang = 'ur' then
      case d.offer_kind
        when 'percent_off' then chr(8294) || d.percent || '%' || chr(8297) || ' رعایت'
        when 'up_to_percent_off' then chr(8294) || d.percent || '%' || chr(8297) || ' تک رعایت'
        when 'flat_percent_off' then 'فلیٹ ' || chr(8294) || d.percent || '%' || chr(8297) || ' رعایت'
        when 'amount_off' then chr(8294) || to_char(d.amount_off_pkr, 'FM999,999,999') || chr(8297) || ' روپے رعایت'
        when 'fixed_price' then chr(8294) || to_char(d.price_pkr, 'FM999,999,999') || chr(8297) || ' روپے'
        else coalesce(d.offer_text_ur, d.offer_text_en)
      end
    else
      case d.offer_kind
        when 'percent_off' then d.percent || '% off'
        when 'up_to_percent_off' then 'Up to ' || d.percent || '% off'
        when 'flat_percent_off' then 'Flat ' || d.percent || '% off'
        when 'amount_off' then 'Rs ' || to_char(d.amount_off_pkr, 'FM999,999,999') || ' off'
        when 'fixed_price' then 'Rs ' || to_char(d.price_pkr, 'FM999,999,999')
        else d.offer_text_en
      end
  end;
$$;

-- Daily push caps by the user's chosen frequency.
create function private.daily_push_cap(f public.alert_frequency) returns integer
language sql immutable set search_path = '' as $$
  select case f when 'low' then 1 when 'normal' then 3 else 6 end;
$$;

-- Plans alerts for up to `max_deals` newly live deals: in-app
-- notifications for everyone who follows something the deal matches (and
-- has that topic on), and pushes for those with push on, within their caps
-- (1/3/6 a day, at most 1 per brand a day), deferred past quiet hours in
-- their own time zone. Returns the number of pushes planned.
create function private.plan_alerts(max_deals integer default 20) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  job record;
  d public.deals;
  b public.brands;
  planned integer := 0;
  n integer;
begin
  -- Recipients of one deal at a time; dropped at the end of the transaction.
  if to_regclass('pg_temp.alert_recipients') is null then
    create temp table alert_recipients (
      user_id uuid, locale text, push boolean, frequency public.alert_frequency,
      time_zone text, quiet_start time, quiet_end time
    ) on commit drop;
  end if;

  -- Rows the planner can finish now: live deals, and deals that are no
  -- longer published or have ended. Deals that are not live yet wait.
  for job in
    select q.deal_id from private.alert_queue q
    join public.deals dd on dd.id = q.deal_id
    join public.brands bb on bb.id = dd.brand_id
    where q.processed_at is null
      and (dd.status <> 'published'
           or (dd.ends_at is not null and dd.ends_at <= now())
           or (dd.starts_at <= now() and bb.is_active))
    order by q.queued_at
    limit least(greatest(max_deals, 1), 200)
    for update of q skip locked
  loop
    select * into d from public.deals where id = job.deal_id;
    select * into b from public.brands where id = d.brand_id;

    if private.is_live(d.status, d.starts_at, d.ends_at) and b.is_active then
      truncate pg_temp.alert_recipients;

      insert into pg_temp.alert_recipients
      with candidates as (
        select f.user_id, 1 as priority, 'brand' as topic
        from public.follows f where f.brand_id = d.brand_id
        union all
        select f.user_id, 2, 'category' from public.follows f
        where f.category_id = d.category_id
           or f.category_id = (select c.parent_id from public.categories c where c.id = d.category_id)
        union all
        select f.user_id, 3, 'cards' from public.follows f
        where f.bank_id in (select co.bank_id from public.card_offers co where co.deal_id = d.id)
        union all
        select uc.user_id, 3, 'cards'
        from public.user_cards uc
        join public.card_products cp on cp.id = uc.card_product_id
        join public.card_offers co on co.deal_id = d.id and co.bank_id = cp.bank_id
          and (co.card_product_id is null or co.card_product_id = cp.id)
          and (co.card_kind is null or co.card_kind = cp.kind)
          and (co.card_network is null or co.card_network = cp.network)
        union all
        select f.user_id, 4, 'city' from public.follows f
        join public.deal_targets t on t.deal_id = d.id and t.city_id = f.city_id
        where d.scope = 'local'
      )
      -- One alert per user, for the first matching topic they have on.
      select distinct on (c.user_id)
        c.user_id, p.locale, ap.push_enabled, ap.frequency, ap.time_zone,
        ap.quiet_start, ap.quiet_end
      from candidates c
      join public.alert_prefs ap on ap.user_id = c.user_id
      join public.profiles p on p.id = c.user_id
      where case c.topic
              when 'brand' then ap.followed_brands
              when 'category' then ap.followed_categories
              when 'cards' then ap.my_cards
              else ap.my_city
            end
      order by c.user_id, c.priority;

      -- In-app inbox, in each user's language. No personal data.
      insert into public.notifications (user_id, kind, title, body, deal_id)
      select r.user_id, 'deal_alert',
             left(case r.locale when 'ur' then coalesce(b.name_ur, b.name) || ': ' || private.offer_headline(d, 'ur')
                                else b.name || ': ' || private.offer_headline(d, 'en') end, 120),
             left(case r.locale when 'ur' then coalesce(d.title_ur, d.title_en) else d.title_en end, 300),
             d.id
      from pg_temp.alert_recipients r;

      -- Pushes: devices registered, push on, quiet hours, caps.
      insert into private.push_outbox (user_id, deal_id, brand_id, local_day, title, body, send_at)
      select r.user_id, d.id, d.brand_id, s.local_day,
             left(case r.locale when 'ur' then coalesce(b.name_ur, b.name) || ': ' || private.offer_headline(d, 'ur')
                                else b.name || ': ' || private.offer_headline(d, 'en') end, 120),
             left(case r.locale when 'ur' then coalesce(d.title_ur, d.title_en) else d.title_en end, 300),
             s.send_at
      from pg_temp.alert_recipients r
      cross join lateral (
        select (now() at time zone r.time_zone) as local_now
      ) l
      cross join lateral (
        select case
          when r.quiet_start < r.quiet_end then
            l.local_now::time >= r.quiet_start and l.local_now::time < r.quiet_end
          else
            l.local_now::time >= r.quiet_start or l.local_now::time < r.quiet_end
        end as quiet
      ) q
      cross join lateral (
        -- Outside quiet hours: now. Inside: when they end (tomorrow if the
        -- quiet period started tonight).
        select case when not q.quiet then now()
                    else ((case when r.quiet_start > r.quiet_end and l.local_now::time >= r.quiet_start
                                then l.local_now::date + 1 else l.local_now::date end)
                          + r.quiet_end) at time zone r.time_zone
               end as send_at
      ) w
      cross join lateral (
        select w.send_at as send_at, (w.send_at at time zone r.time_zone)::date as local_day
      ) s
      where r.push
        and exists (select 1 from public.push_tokens t where t.user_id = r.user_id)
        and (select count(*) from private.push_outbox o
             where o.user_id = r.user_id and o.local_day = s.local_day)
            < private.daily_push_cap(r.frequency)
        and not exists (select 1 from private.push_outbox o
                        where o.user_id = r.user_id and o.local_day = s.local_day
                          and o.brand_id = d.brand_id);
      get diagnostics n = row_count;
      planned := planned + n;
      update private.alert_queue set processed_at = now(), alerted_at = now()
      where deal_id = job.deal_id;
    else
      update private.alert_queue set processed_at = now() where deal_id = job.deal_id;
    end if;
  end loop;
  return planned;
end $$;

-- The dispatcher's side (it connects with the database URL, so these stay
-- private). Claims due pushes, one row per device token; a claim that isn't
-- marked sent within 10 minutes is retried, up to 5 attempts.
create function private.claim_due_pushes(batch integer default 500)
returns table (outbox_id bigint, token text, platform text, title text, body text, deal_id uuid)
language sql volatile security definer set search_path = '' as $$
  with due as (
    select o.id from private.push_outbox o
    where o.sent_at is null and o.send_at <= now() and o.attempts < 5
      and (o.claimed_at is null or o.claimed_at < now() - interval '10 minutes')
    order by o.send_at
    limit least(greatest(batch, 1), 1000)
    for update skip locked
  ),
  claimed as (
    update private.push_outbox o set claimed_at = now(), attempts = o.attempts + 1
    from due where o.id = due.id
    returning o.id, o.user_id, o.title, o.body, o.deal_id
  )
  select c.id, t.token, t.platform, c.title, c.body, c.deal_id
  from claimed c join public.push_tokens t on t.user_id = c.user_id;
$$;

create function private.mark_pushes_sent(outbox_ids bigint[]) returns integer
language sql volatile security definer set search_path = '' as $$
  with done as (
    update private.push_outbox set sent_at = now()
    where id = any(outbox_ids) and sent_at is null
    returning 1
  )
  select count(*)::integer from done;
$$;

-- FCM said these tokens are dead (UNREGISTERED, SENDER_ID_MISMATCH, or an
-- INVALID_ARGUMENT about the registration token).
create function private.drop_push_tokens(tokens text[]) returns integer
language sql volatile security definer set search_path = '' as $$
  with gone as (delete from public.push_tokens where token = any(tokens) returning 1)
  select count(*)::integer from gone;
$$;

-- Old rows that no longer serve a purpose.
create function private.cleanup_old_rows() returns void
language sql volatile security definer set search_path = '' as $$
  delete from private.push_outbox where coalesce(sent_at, created_at) < now() - interval '30 days';
  -- Alerted rows stay: they stop a deal from alerting twice.
  delete from private.alert_queue
  where alerted_at is null and processed_at < now() - interval '7 days';
  delete from public.notifications where created_at < now() - interval '90 days';
$$;

-- (New functions are not executable by PUBLIC: default privileges from the
-- foundation migration. The jobs run as the database owner.)

-- ===========================================================================
-- Schedules (pg_cron). On hosted Supabase the push-dispatcher Edge Function
-- is called every minute through pg_net, with the project URL and the
-- dispatcher secret read from Vault (see docs/backend/JOBS.md).
-- ===========================================================================
create extension if not exists pg_cron;

select cron.schedule('expire-deals', '*/5 * * * *', 'select private.expire_deals()');
select cron.schedule('refresh-freshness', '17 * * * *', 'select private.refresh_freshness()');
select cron.schedule('plan-alerts', '*/2 * * * *', 'select private.plan_alerts(50)');
select cron.schedule('cleanup-old-rows', '43 3 * * *', 'select private.cleanup_old_rows()');

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net')
     and exists (select 1 from pg_namespace where nspname = 'vault') then
    create extension if not exists pg_net;
    perform cron.schedule('push-dispatcher', '* * * * *', $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
               || '/functions/v1/push-dispatcher',
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-dispatcher-secret',
          (select decrypted_secret from vault.decrypted_secrets where name = 'dispatcher_secret')),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000)
    $job$);
  end if;
end $$;
