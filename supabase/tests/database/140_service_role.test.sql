-- The service role (Edge Functions, ingestion, jobs) passes guards and RLS.
begin;
select plan(4);

create temp table w as select * from tests.make_world();
grant select on w to service_role;
set local role service_role;

select lives_ok($$ update public.deals set status = 'published', verified_at = now()
  where id = (select review_a from w) $$, 'ingestion publishes and verifies deals');
select lives_ok($$ insert into public.notifications (user_id, kind, title, deal_id)
  select shopper, 'deal_alert', 'Kolachi: 20% off tonight', live_a from w $$,
  'the push dispatcher writes notifications');
select lives_ok($$ insert into public.payments (business_id, amount_pkr, provider, provider_ref, status, paid_at)
  select biz_a, 5000, 'easypaisa', 'EP-778899', 'paid', now() from w $$,
  'the payments webhook records payments');
select lives_ok($$ update public.businesses set status = 'verified', verified_at = now()
  where id = (select biz_a from w) $$, 'jobs and staff tools can verify businesses');

select * from finish();
rollback;
