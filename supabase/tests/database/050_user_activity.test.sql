begin;
select plan(12);

create temp table u as select tests.create_user() as id;
create temp table f as select tests.make_brand() as brand, tests.make_city() as city,
                              tests.make_bank() as bank;

select lives_ok($$
  insert into public.follows (user_id, brand_id) select u.id, f.brand from u, f
$$, 'follow a brand');
select throws_ok($$
  insert into public.follows (user_id, brand_id) select u.id, f.brand from u, f
$$, '23505', null, 'following twice is rejected');
select throws_ok($$
  insert into public.follows (user_id, brand_id, city_id) select u.id, f.brand, f.city from u, f
$$, '23514', null, 'a follow has exactly one target');
select throws_ok($$
  insert into public.follows (user_id) select id from u
$$, '23514', null, 'a follow needs a target');

select lives_ok($$
  insert into public.saves (user_id, deal_id) select id, tests.make_deal(f.brand) from u, f
$$, 'save a deal');
select lives_ok($$
  insert into public.user_cards (user_id, card_product_id)
  select u.id, tests.make_card_product(f.bank) from u, f
$$, 'add a card product');

select throws_ok($$
  update public.alert_prefs set quiet_start = '22:00', quiet_end = '22:00'
  where user_id = (select id from u)
$$, '23514', null, 'quiet hours need a start and an end');
select throws_ok($$
  update public.alert_prefs set time_zone = 'Asia/Karachi; drop table x'
  where user_id = (select id from u)
$$, '23514', null, 'time zones are IANA names');

select throws_ok($$
  insert into public.notifications (user_id, kind, title, created_at, read_at)
  select id, 'system', 'Welcome', now(), now() - interval '1 hour' from u
$$, '23514', null, 'a notification cannot be read before it was sent');

-- Deleting the account removes everything the user kept.
insert into public.notifications (user_id, kind, title) select id, 'system', 'Welcome' from u;
delete from auth.users where id = (select id from u);
select is((select count(*)::int from public.follows where user_id = (select id from u))
        + (select count(*)::int from public.saves where user_id = (select id from u))
        + (select count(*)::int from public.user_cards where user_id = (select id from u))
        + (select count(*)::int from public.notifications where user_id = (select id from u))
        + (select count(*)::int from public.alert_prefs where user_id = (select id from u)), 0,
  'follows, saves, cards, notifications and alert prefs go with the account');

-- Deleting a deal removes saves but keeps the notification (unlinked).
create temp table d as select tests.make_deal() as id, tests.create_user() as uid;
insert into public.saves (user_id, deal_id) select uid, id from d;
insert into public.notifications (user_id, kind, title, deal_id) select uid, 'deal_alert', 'Sale', id from d;
delete from public.deals where id = (select id from d);
select is((select count(*)::int from public.saves where user_id = (select uid from d)), 0,
  'saves of a deleted deal are removed');
select is((select deal_id from public.notifications where user_id = (select uid from d)), null,
  'notifications of a deleted deal stay, unlinked');

select * from finish();
rollback;
