-- Moderation workflow (sub-phase 3.5): the review queue, duplicate
-- detection and the actions moderators take on submissions. Everything
-- here runs as the moderator (security invoker), so RLS still decides
-- what they can see and change; staff powers need an MFA session.

-- ---------------------------------------------------------------------------
-- Queue: what needs a moderator, oldest first. One row per item.
-- ---------------------------------------------------------------------------
create view public.moderation_queue with (security_invoker = true) as
select 'submission'::text as item_type, s.id as item_id, s.created_at as waiting_since,
       s.title, s.brand_name, s.brand_id, null::uuid as deal_id, 0::bigint as open_reports
from public.submissions s
where s.status = 'pending'
union all
select 'deal_review', d.id, d.updated_at, d.title_en, b.name::text, d.brand_id, d.id, 0
from public.deals d join public.brands b on b.id = d.brand_id
where d.status = 'pending_review'
union all
select 'reported_deal', d.id, min(r.created_at), d.title_en, b.name::text, d.brand_id, d.id, count(*)
from public.reports r
join public.deals d on d.id = r.deal_id
join public.brands b on b.id = d.brand_id
where r.status = 'open'
group by d.id, d.title_en, b.name, d.brand_id;

grant select on public.moderation_queue to authenticated;

-- ---------------------------------------------------------------------------
-- Duplicates: live or waiting deals of the same brand (or, when the
-- submission names no known brand, any brand) with a similar title.
-- ---------------------------------------------------------------------------
create function public.submission_duplicates(submission_id uuid, min_similarity real default 0.45)
returns table (deal_id uuid, title text, brand_name text, status public.deal_status, similarity real)
language sql stable security invoker set search_path = '' as $$
  select d.id, d.title_en, b.name::text, d.status,
         extensions.similarity(s.title, d.title_en) as similarity
  from public.submissions s
  join public.deals d on (s.brand_id is null or d.brand_id = s.brand_id)
  join public.brands b on b.id = d.brand_id
  where s.id = submission_duplicates.submission_id
    and d.status in ('published', 'pending_review', 'draft')
    and extensions.similarity(s.title, d.title_en) >= greatest(min_similarity, 0.2)
  order by similarity desc, d.published_at desc nulls last
  limit 10;
$$;

-- ---------------------------------------------------------------------------
-- Actions. Each checks the submission is still pending (two moderators
-- can't both act on it) and records who decided.
-- ---------------------------------------------------------------------------

-- Approve: create the deal from the moderator's edited fields and link it.
-- `deal` uses the deals table's column names (brand_id, category_id, kind,
-- scope, title_en, offer_kind, percent, ...); status defaults to published.
create function public.approve_submission(submission_id uuid, deal jsonb) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  sub public.submissions;
  new_id uuid;
begin
  if not private.is_moderator() then
    raise exception 'moderators only (with MFA)' using errcode = '42501';
  end if;
  select * into sub from public.submissions s where s.id = submission_id for update;
  if sub.id is null then
    raise exception 'no such submission' using errcode = 'P0002';
  end if;
  if sub.status <> 'pending' then
    raise exception 'submission already %', sub.status using errcode = '55000';
  end if;

  insert into public.deals (
    brand_id, category_id, kind, scope, status, source, title_en, title_ur,
    description_en, offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr,
    offer_text_en, promo_code, url, image_path, starts_at, ends_at, verified_at)
  select r.brand_id, r.category_id, r.kind, r.scope, coalesce(r.status, 'published'),
         'user_submission', r.title_en, r.title_ur, r.description_en, r.offer_kind, r.percent,
         r.amount_off_pkr, r.price_pkr, r.original_price_pkr, r.offer_text_en, r.promo_code,
         r.url, r.image_path, coalesce(r.starts_at, now()), coalesce(r.ends_at, sub.ends_at), now()
  from jsonb_populate_record(null::public.deals, deal) r
  returning id into new_id;

  if deal ? 'city_ids' then
    insert into public.deal_targets (deal_id, city_id)
    select new_id, c::uuid from jsonb_array_elements_text(deal -> 'city_ids') c;
  end if;

  update public.submissions set
    status = 'approved', deal_id = new_id, brand_id = coalesce(sub.brand_id, (deal ->> 'brand_id')::uuid),
    reviewer_id = (select auth.uid()), reviewed_at = now()
  where id = sub.id;
  return new_id;
end $$;

create function public.reject_submission(submission_id uuid, reason text) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  n integer;
begin
  if not private.is_moderator() then
    raise exception 'moderators only (with MFA)' using errcode = '42501';
  end if;
  update public.submissions set status = 'rejected', reject_reason = btrim(reason),
    reviewer_id = (select auth.uid()), reviewed_at = now()
  where id = submission_id and status = 'pending';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'no pending submission %', submission_id using errcode = '55000';
  end if;
end $$;

create function public.mark_submission_duplicate(submission_id uuid, existing_deal uuid) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  n integer;
begin
  if not private.is_moderator() then
    raise exception 'moderators only (with MFA)' using errcode = '42501';
  end if;
  update public.submissions set status = 'duplicate', duplicate_of = existing_deal,
    reviewer_id = (select auth.uid()), reviewed_at = now()
  where id = submission_id and status = 'pending';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'no pending submission %', submission_id using errcode = '55000';
  end if;
end $$;

revoke execute on function public.submission_duplicates(uuid, real), public.approve_submission(uuid, jsonb),
  public.reject_submission(uuid, text), public.mark_submission_duplicate(uuid, uuid) from public, anon;
grant execute on function public.submission_duplicates(uuid, real), public.approve_submission(uuid, jsonb),
  public.reject_submission(uuid, text), public.mark_submission_duplicate(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Tell the submitter how their submission went, in their language.
-- ---------------------------------------------------------------------------
create function private.notify_submitter() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  lang text;
begin
  if new.submitter_id is null then
    return null;
  end if;
  select p.locale into lang from public.profiles p where p.id = new.submitter_id;
  insert into public.notifications (user_id, kind, title, body, deal_id)
  values (
    new.submitter_id, 'system',
    case new.status
      when 'approved' then case lang when 'ur' then 'آپ کی ڈیل شائع ہو گئی' else 'Your deal is live' end
      when 'duplicate' then case lang when 'ur' then 'یہ ڈیل پہلے سے موجود ہے' else 'We already have this deal' end
      else case lang when 'ur' then 'آپ کی ڈیل شائع نہیں ہو سکی' else 'Your deal wasn''t published' end
    end,
    left(case new.status when 'rejected' then new.reject_reason else new.title end, 300),
    coalesce(new.deal_id, new.duplicate_of));
  return null;
end $$;
create trigger submissions_notify after update of status on public.submissions
  for each row when (old.status = 'pending' and new.status <> 'pending')
  execute function private.notify_submitter();
