-- Moderation workflow: queue, duplicates, approve / reject / duplicate,
-- and what the submitter is told.
begin;
select plan(19);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
update public.deals set title_en = 'Chicken karahi family deal' where id = (select live_a from w);
update public.profiles set locale = 'ur' where id = (select owner from w);

-- Two shoppers submit deals.
select tests.authenticate_as((select shopper from w));
insert into public.submissions (kind, brand_name, brand_id, title)
  select 'food_deal', 'Kolachi', brand_a, 'Chicken karahi family deal for 4' from w;
insert into public.submissions (kind, brand_name, title) values ('food_deal', 'Unknown Dhaba', 'Free chai with paratha');
select tests.authenticate_as((select owner from w));
insert into public.submissions (kind, brand_name, title) values ('food_deal', 'Some Shop', 'Spam spam spam');
select tests.clear_authentication();
create temp table subs as select
  (select id from public.submissions where title like 'Chicken karahi%') as dup,
  (select id from public.submissions where title like 'Free chai%') as good,
  (select id from public.submissions where title like 'Spam%') as bad;
grant select on subs to authenticated;
insert into public.reports (deal_id, reporter_id, reason) select live_b, tests.create_user(), 'expired' from w;

-- The queue
select tests.staff((select moderator from w));
select is((select count(*)::int from public.moderation_queue where item_type = 'submission'), 3,
  'pending submissions are queued');
select is((select count(*)::int from public.moderation_queue where item_type = 'deal_review'), 1,
  'deals waiting for review are queued');
select is((select open_reports from public.moderation_queue where item_type = 'reported_deal'), 1::bigint,
  'reported deals are queued with their report count');

-- Duplicates
select is((select deal_id from public.submission_duplicates((select dup from subs)) limit 1), (select live_a from w),
  'a similar live deal of the same brand is flagged as a likely duplicate');
select is((select count(*)::int from public.submission_duplicates((select good from subs))), 0,
  'an unrelated submission has no duplicates');

-- Approve
create temp table approved as select public.approve_submission((select good from subs), jsonb_build_object(
  'brand_id', (select brand_b from w), 'category_id', (select category_id from public.brands where id = (select brand_b from w)),
  'kind', 'food_deal', 'scope', 'nationwide', 'title_en', 'Free chai with every paratha',
  'offer_kind', 'text', 'offer_text_en', 'Free chai')) as deal_id;
select results_eq($$ select status::text, source::text, created_by from public.deals where id = (select deal_id from approved) $$,
  $$ select 'published', 'user_submission', moderator from w $$,
  'approving creates a live deal, sourced from the submission, owned by the moderator');
select results_eq($$ select status::text, deal_id, reviewer_id from public.submissions where id = (select good from subs) $$,
  $$ select 'approved', (select deal_id from approved), moderator from w $$,
  'the submission is approved, linked and signed by the moderator');
select throws_ok($$ select public.approve_submission((select good from subs), '{}') $$, '55000', null,
  'a submission can be decided only once');

-- Duplicate and reject
select lives_ok($$ select public.mark_submission_duplicate((select dup from subs), (select live_a from w)) $$,
  'mark a duplicate');
select lives_ok($$ select public.reject_submission((select bad from subs), 'Not a real offer') $$, 'reject one');
select throws_ok($$ select public.reject_submission((select bad from subs), 'Again') $$, '55000', null,
  'rejecting twice fails');

-- What the submitters were told
select tests.clear_authentication();
select results_eq($$ select title, deal_id from public.notifications
  where user_id = (select shopper from w) order by title $$,
  $$ values ('We already have this deal', (select live_a from w)), ('Your deal is live', (select deal_id from approved)) $$,
  'the submitter hears about approval and duplicates, with a link');
select results_eq($$ select title, body from public.notifications where user_id = (select owner from w) $$,
  $$ values ('آپ کی ڈیل شائع نہیں ہو سکی'::text, 'Not a real offer'::text) $$,
  'rejections say why, in the submitter''s language');

-- Who may act
select tests.authenticate_as((select shopper from w));
select throws_ok($$ select public.reject_submission((select good from subs), 'x') $$, '42501', null,
  'shoppers cannot moderate');
select is((select count(*)::int from public.moderation_queue where item_type = 'reported_deal'), 0,
  'and the queue shows them only their own items');
select tests.authenticate_as((select moderator from w));
select throws_ok($$ select public.reject_submission((select good from subs), 'x') $$, '42501', null,
  'moderators need MFA');
select tests.authenticate_as((select editor from w));
select throws_ok($$ select public.approve_submission((select good from subs), '{}') $$, '42501', null,
  'business members cannot approve submissions');
select tests.authenticate_as_anon();
select throws_ok($$ select public.reject_submission((select good from subs), 'x') $$, '42501', null,
  'anon cannot call moderation functions');
select throws_ok($$ select * from public.moderation_queue $$, '42501', null, 'anon cannot read the queue');

select * from finish();
rollback;
