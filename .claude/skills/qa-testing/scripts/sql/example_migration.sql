-- EXAMPLE ONLY: a reduced version of the deals schema that shows the RLS patterns from
-- flutter-secure-dev/references/supabase-security.md. The real migrations live in
-- supabase/migrations/. This file exists so the harness can be self-tested.

create type public.app_role as enum ('business_owner', 'moderator', 'admin');

create table public.user_roles (
  user_id uuid not null references auth.users on delete cascade,
  role public.app_role not null,
  primary key (user_id, role)
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 120)
);

create table public.business_members (
  business_id uuid not null references public.businesses on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  primary key (business_id, user_id)
);

create table public.deals (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete cascade,
  title text not null check (length(title) between 3 and 140),
  status text not null default 'draft' check (status in ('draft', 'published', 'expired', 'removed')),
  ends_at timestamptz
);
create index on public.deals (business_id);
create index on public.deals (status, ends_at);

create table public.reports (
  id bigint generated always as identity primary key,
  deal_id uuid not null references public.deals on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users on delete cascade,
  reason text not null check (reason in ('expired', 'wrong_price', 'closed', 'other')),
  created_at timestamptz not null default now()
);
create index on public.reports (reporter_id, created_at desc);

-- Helpers live in a NON-exposed schema, pin search_path and are only executable by authenticated.
create or replace function private.has_role(r public.app_role) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles ur where ur.user_id = (select auth.uid()) and ur.role = r);
$$;

create or replace function private.my_business_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select bm.business_id from public.business_members bm where bm.user_id = (select auth.uid());
$$;

revoke execute on all functions in schema private from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.has_role(public.app_role), private.my_business_ids() to authenticated;

-- Grants first (deny by default), then RLS, then one policy per operation.
alter table public.user_roles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.deals enable row level security;
alter table public.reports enable row level security;

revoke all on public.user_roles, public.businesses, public.business_members, public.deals, public.reports from anon, authenticated;
grant select on public.businesses, public.deals to anon, authenticated;
grant insert, update on public.deals to authenticated;
grant select on public.business_members to authenticated;
grant insert, select on public.reports to authenticated;
grant usage on sequence public.reports_id_seq to authenticated;

create policy "published deals are public" on public.deals for select to anon, authenticated
  using (status = 'published');
create policy "members see their drafts" on public.deals for select to authenticated
  using (business_id in (select private.my_business_ids()));
create policy "moderators see everything" on public.deals for select to authenticated
  using ((select private.has_role('moderator')) or (select private.has_role('admin')));
create policy "members create deals for their business" on public.deals for insert to authenticated
  with check (business_id in (select private.my_business_ids()) and status = 'draft');
create policy "members update own business deals" on public.deals for update to authenticated
  using (business_id in (select private.my_business_ids()))
  with check (business_id in (select private.my_business_ids()) and status in ('draft', 'published', 'expired'));

create policy "businesses are public" on public.businesses for select to anon, authenticated using (true);
create policy "see own memberships" on public.business_members for select to authenticated
  using (user_id = (select auth.uid()));

create policy "users file reports as themselves" on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
create policy "users read own reports" on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or (select private.has_role('moderator')));

-- Abuse control: at most 10 reports per user per hour, enforced in the database.
create or replace function private.enforce_report_rate_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.reports r
      where r.reporter_id = new.reporter_id and r.created_at > now() - interval '1 hour') >= 10 then
    raise exception 'rate limit: too many reports' using errcode = 'P0429';
  end if;
  return new;
end $$;
create trigger reports_rate_limit before insert on public.reports
  for each row execute function private.enforce_report_rate_limit();
