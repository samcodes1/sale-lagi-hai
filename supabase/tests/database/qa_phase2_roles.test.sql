-- QA, Phase 2 full-phase gate: every RPC and view in `public`, called by
-- every role. The table-level sweep is in qa_rls.test.sql. This file
-- fails if a new public function appears, so the next RPC gets the same
-- review.
begin;
select plan(4);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
grant select on w to anon, authenticated;

select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prokind = 'f'),
  array['approve_submission', 'brand_deals', 'custom_access_token_hook', 'deals_for_my_cards',
        'featured_deals', 'feed', 'mark_submission_duplicate', 'nearby_deals', 'register_push_token',
        'reject_submission', 'search_deals', 'submission_duplicates', 'trending_deals'],
  'the public RPC surface is exactly the reviewed set');

-- One pending submission per staff action, so each call has work to do.
create temp table subs (g int, id uuid);
insert into public.submissions (submitter_id, kind, brand_name, title)
  select (select shopper from w), 'other', 'Brand', 'Submission ' || g from generate_series(1, 12) g;
insert into subs select row_number() over (order by length(title), title), id from public.submissions where title like 'Submission %';
grant select on subs to anon, authenticated;

create temp table calls (who text, rpc text, code text);
grant all on calls to anon, authenticated;
create function pg_temp.call_all(who text, n int) returns void language plpgsql as $$
declare
  r record;
  code text;
  sub uuid := (select id from subs where g = n);
begin
  for r in select * from (values
    ('feed', 'select count(*) from public.feed(null, null, true)'),
    ('featured_deals', 'select count(*) from public.featured_deals(''home_featured'')'),
    ('trending_deals', 'select count(*) from public.trending_deals()'),
    ('nearby_deals', 'select count(*) from public.nearby_deals(24.86, 67.0, 3000)'),
    ('search_deals', 'select count(*) from public.search_deals(''winter'')'),
    ('brand_deals', 'select count(*) from public.brand_deals(''kolachi'')'),
    ('deals_for_my_cards', 'select count(*) from public.deals_for_my_cards()'),
    ('register_push_token', format('select public.register_push_token(%L, ''android'')', who || '-device-0000000000000000')),
    ('custom_access_token_hook', 'select public.custom_access_token_hook(''{"user_id": null}'')'),
    ('submission_duplicates', format('select count(*) from public.submission_duplicates(%L)', sub)),
    ('approve_submission', format('select public.approve_submission(%L, %L::jsonb)', sub,
       jsonb_build_object('brand_id', (select brand_b from w), 'category_id',
         (select category_id from public.brands where id = (select brand_b from w)),
         'kind', 'other', 'scope', 'nationwide', 'title_en', 'Approved by ' || who,
         'offer_kind', 'text', 'offer_text_en', 'Deal'))),
    ('reject_submission', format('select public.reject_submission(%L, ''not a real deal'')',
       (select id from subs where g = n + 6))),
    ('moderation_queue', 'select count(*) from public.moderation_queue'),
    ('stale_deals', 'select count(*) from public.stale_deals'),
    ('deal_cards', 'select count(*) from public.deal_cards')
  ) v(rpc, q) loop
    begin
      execute r.q;
      code := 'ok';
    exception when others then
      code := sqlstate;
    end;
    insert into calls values (who, r.rpc, code);
  end loop;
end $$;
grant execute on function pg_temp.call_all(text, int) to anon, authenticated;

select tests.authenticate_as_anon(); select pg_temp.call_all('anon', 1); select tests.clear_authentication();
select tests.authenticate_as((select shopper from w)); select pg_temp.call_all('shopper', 2); select tests.clear_authentication();
select tests.authenticate_as((select owner from w)); select pg_temp.call_all('owner', 3); select tests.clear_authentication();
select tests.authenticate_as((select moderator from w)); select pg_temp.call_all('moderator_aal1', 4); select tests.clear_authentication();
select tests.staff((select moderator from w)); select pg_temp.call_all('moderator_aal2', 5); select tests.clear_authentication();
select tests.staff((select admin from w)); select pg_temp.call_all('admin_aal2', 6); select tests.clear_authentication();

-- What each role may call. Reads are open to all; my-cards, devices and
-- submission tools need a session; staff actions need MFA; the token hook
-- is for supabase_auth_admin only.
create temp table expected (who text, rpc text, code text);
insert into expected
select who, rpc, case
    when rpc = 'custom_access_token_hook' then '42501'
    when who = 'anon' and rpc in ('deals_for_my_cards', 'register_push_token', 'submission_duplicates',
                                  'approve_submission', 'reject_submission', 'moderation_queue', 'stale_deals') then '42501'
    when rpc in ('approve_submission', 'reject_submission')
         and who not in ('moderator_aal2', 'admin_aal2') then '42501'
    else 'ok' end
from unnest(array['anon', 'shopper', 'owner', 'moderator_aal1', 'moderator_aal2', 'admin_aal2']) who,
     (select distinct rpc from calls) r;

select is(
  (select string_agg(format('%s/%s: %s (want %s)', c.who, c.rpc, c.code, e.code), '; ' order by c.who, c.rpc)
   from calls c join expected e using (who, rpc) where c.code <> e.code),
  null, 'every role gets exactly the expected answer from every RPC and view');
select is((select count(*) from calls), 90::bigint, 'six roles called fifteen RPCs and views');

-- What non-staff see in the staff views.
select tests.authenticate_as((select shopper from w));
select is((select count(*) from public.stale_deals), 0::bigint, 'shoppers see no stale-deal list');
select tests.clear_authentication();

select * from finish();
rollback;
