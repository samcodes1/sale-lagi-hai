-- Moderation (reports, submissions), paid placements and payments, and the
-- audit log.

-- ---------------------------------------------------------------------------
-- Reports: "this deal is wrong". One per user per deal. Kept when the
-- reporter deletes their account, without their id.
-- ---------------------------------------------------------------------------
create type public.report_reason as enum (
  'expired', 'wrong_price', 'wrong_place', 'closed', 'spam', 'offensive', 'other'
);
create type public.report_status as enum ('open', 'resolved', 'dismissed');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.deals on delete cascade,
  reporter_id uuid default auth.uid() references auth.users on delete set null,
  reason public.report_reason not null,
  note text check (length(note) <= 500),
  status public.report_status not null default 'open',
  resolved_by uuid references auth.users on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (deal_id, reporter_id),
  check ((status = 'open') = (resolved_at is null)),
  check (reason <> 'other' or note is not null)
);
create index reports_open_idx on public.reports (created_at) where status = 'open';
create index reports_reporter_idx on public.reports (reporter_id, created_at desc);
create index reports_resolved_by_idx on public.reports (resolved_by);

-- ---------------------------------------------------------------------------
-- Submissions: deals sent in by shoppers or businesses, waiting for review.
-- A moderator approves (creating a deal), rejects or marks a duplicate.
-- ---------------------------------------------------------------------------
create type public.submission_status as enum ('pending', 'approved', 'rejected', 'duplicate');

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  submitter_id uuid default auth.uid() references auth.users on delete set null,
  kind public.deal_kind not null,
  brand_name public.short_name not null,
  brand_id uuid references public.brands on delete set null,
  title text not null check (length(btrim(title)) between 3 and 140),
  details text check (length(details) <= 2000),
  url public.https_url,
  city_id uuid references public.cities on delete set null,
  image_path public.storage_path,
  ends_at timestamptz,
  status public.submission_status not null default 'pending',
  deal_id uuid references public.deals on delete set null,
  duplicate_of uuid references public.deals on delete set null,
  reviewer_id uuid references auth.users on delete set null,
  reviewed_at timestamptz,
  reject_reason text check (length(reject_reason) between 3 and 300),
  created_at timestamptz not null default now(),
  check ((status = 'pending') = (reviewed_at is null)),
  check (status <> 'rejected' or reject_reason is not null),
  check (status <> 'duplicate' or duplicate_of is not null)
);
create index submissions_pending_idx on public.submissions (created_at)
  where status = 'pending';
create index submissions_submitter_idx on public.submissions (submitter_id, created_at desc);
create index submissions_deal_idx on public.submissions (deal_id);
create index submissions_duplicate_idx on public.submissions (duplicate_of);
create index submissions_brand_idx on public.submissions (brand_id);
create index submissions_city_idx on public.submissions (city_id);
create index submissions_reviewer_idx on public.submissions (reviewer_id);

-- ---------------------------------------------------------------------------
-- Placements: paid "Featured" slots, always labelled in the app.
-- ---------------------------------------------------------------------------
create type public.placement_slot as enum (
  'home_featured', 'category_top', 'search_top', 'city_spotlight'
);
create type public.placement_status as enum (
  'draft', 'scheduled', 'active', 'ended', 'cancelled'
);

create table public.placements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete cascade,
  deal_id uuid not null references public.deals on delete cascade,
  slot public.placement_slot not null,
  -- Null: every city (nationwide placements).
  city_id uuid references public.cities on delete restrict,
  category_id uuid references public.categories on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.placement_status not null default 'draft',
  -- Higher wins when slots compete.
  priority smallint not null default 0 check (priority between 0 and 100),
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (ends_at - starts_at <= interval '90 days'),
  check (slot <> 'category_top' or category_id is not null),
  check (slot <> 'city_spotlight' or city_id is not null)
);
create index placements_business_idx on public.placements (business_id);
create index placements_deal_idx on public.placements (deal_id);
create index placements_city_idx on public.placements (city_id);
create index placements_category_idx on public.placements (category_id);
create index placements_created_by_idx on public.placements (created_by);
create index placements_live_idx on public.placements (slot, starts_at, ends_at)
  where status in ('scheduled', 'active');

-- A business can only promote deals of its own brands.
create function private.check_placement_deal() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.deals d join public.brands b on b.id = d.brand_id
    where d.id = new.deal_id and b.business_id = new.business_id
  ) then
    raise exception 'a placement must promote one of the business''s own deals'
      using errcode = '23514';
  end if;
  return new;
end $$;
revoke execute on function private.check_placement_deal() from public;
create trigger placements_deal before insert or update of deal_id, business_id
  on public.placements for each row execute function private.check_placement_deal();

create type public.payment_provider as enum (
  'jazzcash', 'easypaisa', 'bank_transfer', 'card', 'manual'
);
create type public.payment_status as enum ('pending', 'paid', 'failed', 'refunded');

-- Written by the payments webhook (service role) and staff only.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete restrict,
  placement_id uuid references public.placements on delete set null,
  amount_pkr public.pkr not null check (amount_pkr > 0),
  provider public.payment_provider not null,
  -- The provider's transaction id: one payment per transaction.
  provider_ref text check (length(provider_ref) between 3 and 120),
  status public.payment_status not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_ref),
  check ((status in ('paid', 'refunded')) = (paid_at is not null)),
  check (provider = 'manual' or status = 'pending' or provider_ref is not null)
);
create index payments_business_idx on public.payments (business_id, created_at desc);
create index payments_placement_idx on public.payments (placement_id);

create trigger placements_touch before update on public.placements
  for each row execute function private.touch_updated_at();
create trigger payments_touch before update on public.payments
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Audit log: who changed roles, memberships, business status, deal status,
-- placements and payments. Written only by the trigger below; read by
-- admins.
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  -- The signed-in user, or null for the service role and jobs.
  actor_id uuid,
  action text not null check (action in ('insert', 'update', 'delete')),
  table_name text not null,
  row_id text not null,
  old_data jsonb,
  new_data jsonb
);
create index audit_log_row_idx on public.audit_log (table_name, row_id, at desc);
create index audit_log_actor_idx on public.audit_log (actor_id, at desc);

create function private.audit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  old_row jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  new_row jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  row_key jsonb := coalesce(new_row, old_row);
begin
  insert into public.audit_log (actor_id, action, table_name, row_id, old_data, new_data)
  values (
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    coalesce(row_key ->> 'id',
             concat_ws(':', row_key ->> 'business_id', row_key ->> 'user_id', row_key ->> 'role')),
    old_row,
    new_row
  );
  return null;
end $$;
revoke execute on function private.audit() from public;

create trigger user_roles_audit after insert or update or delete on public.user_roles
  for each row execute function private.audit();
create trigger business_members_audit after insert or update or delete on public.business_members
  for each row execute function private.audit();
-- Any update, not just `update of status`: guard_business also changes
-- the status itself (a verified business that renames goes back to review).
create trigger businesses_status_audit after update on public.businesses
  for each row when (old.status is distinct from new.status)
  execute function private.audit();
create trigger businesses_delete_audit after delete on public.businesses
  for each row execute function private.audit();
create trigger deals_status_audit after update of status on public.deals
  for each row when (old.status is distinct from new.status)
  execute function private.audit();
create trigger deals_delete_audit after delete on public.deals
  for each row execute function private.audit();
create trigger placements_audit after insert or update or delete on public.placements
  for each row execute function private.audit();
create trigger payments_audit after insert or update or delete on public.payments
  for each row execute function private.audit();
create trigger reports_audit after update of status on public.reports
  for each row when (old.status is distinct from new.status)
  execute function private.audit();

alter table public.reports enable row level security;
alter table public.submissions enable row level security;
alter table public.placements enable row level security;
alter table public.payments enable row level security;
alter table public.audit_log enable row level security;
