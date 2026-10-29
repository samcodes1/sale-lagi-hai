begin;
select plan(9);

create temp table w as select * from tests.make_world();
grant select on w to authenticated;
update public.deals set url = 'https://example.com/a', verified_at = now() where id = (select live_a from w);
update public.deals set url = 'https://example.com/b', verified_at = now() - interval '30 days' where id = (select live_b from w);

select is((select count(*)::int from private.links_to_check()), 2, 'live deals with links are due for a check');
select private.record_link_check((select live_a from w), 'broken');
select private.record_link_check((select live_a from w), 'unknown');
select is((select link_failures from public.deals where id = (select live_a from w)), 1::smallint,
  'a broken link counts; network trouble does not');
select is((select count(*)::int from private.links_to_check()), 1, 'a checked link is not checked again today');
select private.record_link_check((select live_a from w), 'ok');
select is((select link_failures from public.deals where id = (select live_a from w)), 0::smallint,
  'a working link clears the count');
update public.deals set link_failures = 3 where id = (select live_a from w);

select tests.staff((select moderator from w));
select results_eq($$ select id, reasons from public.stale_deals order by id $$,
  $$ select * from (values ((select live_a from w), array['broken_link']), ((select live_b from w), array['not_verified'])) v(id, r) order by 1 $$,
  'stale deals list why they are stale');
select ok(not exists (select 1 from public.stale_deals where id = (select draft_a from w)), 'only live deals');
select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.stale_deals), 0, 'staleness flags are for staff only');
select tests.clear_authentication();
select is(private.notify_staleness(), 1, 'the admin is told once');
select ok(exists (select 1 from public.notifications where user_id = (select admin from w) and title = '2 deals need checking'),
  'with the count');

select * from finish();
rollback;
