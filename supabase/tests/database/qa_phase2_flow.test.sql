-- QA, Phase 2 full-phase gate: the main flows end to end, across 2.1-2.6
-- (and the Phase 3 moderation RPC where the flow passes through it), on
-- the seeded reference data. Each step runs as the role that does it in
-- the product: a business owner, staff with MFA, shoppers, anon, and the
-- jobs as the database owner.
begin;
select plan(42);

-- SQLSTATE of a statement run as the current role ('ok' when it succeeds).
create function pg_temp.state(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.state(text) to anon, authenticated;

-- Cast: a new business owner, staff, and three shoppers.
create temp table cast_ as select
  tests.create_user('cafe-owner@example.com') as owner,
  tests.create_user('mod2@example.com') as moderator,
  tests.create_user('admin2@example.com') as admin,
  tests.create_user('fan-en@example.com') as fan_en,
  tests.create_user('fan-ur@example.com') as fan_ur,
  tests.create_user('nobody@example.com') as stranger;
insert into public.user_roles (user_id, role)
  select moderator, 'moderator'::public.app_role from cast_ union all select admin, 'admin'::public.app_role from cast_;
create temp table ids (k text primary key, v uuid);
insert into ids select 'karachi', id from public.cities where slug = 'karachi';
insert into ids select 'clifton', a.id from public.areas a join public.cities c on c.id = a.city_id
  where c.slug = 'karachi' and a.slug = 'clifton';
insert into ids select 'cafes', id from public.categories where slug = 'cafes-and-desserts';
grant select on cast_, ids to anon, authenticated;
grant all on ids to authenticated;
create function pg_temp.id(key text) returns uuid language sql stable as $$ select v from ids where k = key $$;
grant execute on function pg_temp.id(text) to anon, authenticated;

-- 1. A shopper registers a business and becomes its owner.
select tests.authenticate_as((select owner from cast_));
select is(pg_temp.state($$ with x as (insert into public.businesses (name, contact_phone) values ('Chai Corner', '+923001234567')
                          returning id) insert into ids select 'biz', id from x $$), 'ok', 'a shopper registers a business');
select is((select role::text from public.business_members where business_id = pg_temp.id('biz')), 'owner',
  'and is its owner');

-- 2. They add their brand with a placeholder slug, hidden.
select is(pg_temp.state($$ insert into public.brands (slug, name, business_id, category_id, is_active)
  values ('khaadi', 'Chai Corner', pg_temp.id('biz'), pg_temp.id('cafes'), false) $$), '42501',
  'a business cannot claim a real-looking slug');
select is(pg_temp.state($$ with x as (insert into public.brands (slug, name, business_id, category_id, is_active)
  values ('pending-chai-corner', 'Chai Corner', pg_temp.id('biz'), pg_temp.id('cafes'), false) returning id) insert into ids select 'brand', id from x $$),
  'ok', 'it adds its brand with a pending- slug');
select tests.clear_authentication();
select tests.authenticate_as_anon();
select is((select count(*) from public.brands where id = pg_temp.id('brand')), 0::bigint, 'the new brand is hidden');
select tests.clear_authentication();

-- 3. Staff with MFA verify the business, and give the brand its slug and
--    the badge.
select tests.authenticate_as((select moderator from cast_));
select is(pg_temp.state($$ update public.brands set is_active = true where id = pg_temp.id('brand') $$), 'ok',
  'without MFA a moderator ...');
select tests.clear_authentication();
select is((select is_active from public.brands where id = pg_temp.id('brand')), false, '... changes nothing');
select tests.staff((select moderator from cast_));
select is(pg_temp.state($$ update public.businesses set status = 'verified', verified_at = now()
  where id = pg_temp.id('biz') $$), 'ok', 'a moderator verifies the business');
select is(pg_temp.state($$ update public.brands set slug = 'chai-corner', is_active = true, is_verified = true
  where id = pg_temp.id('brand') $$), 'ok', 'and activates and verifies the brand under its real slug');
select tests.clear_authentication();

-- Shoppers follow the brand (one in Urdu); both have a device and push on.
update public.profiles set locale = 'ur' where id = (select fan_ur from cast_);
select tests.authenticate_as((select fan_en from cast_));
select is(pg_temp.state($$ insert into public.follows (user_id, brand_id) values (auth.uid(), pg_temp.id('brand')) $$),
  'ok', 'a shopper follows the brand');
select is(pg_temp.state($$ select public.register_push_token('fan-en-device-token-000000000001', 'android') $$), 'ok',
  'and registers a device');
select is(pg_temp.state($$ update public.alert_prefs set push_enabled = true,
  quiet_start = ((now() at time zone 'Asia/Karachi')::time + interval '2 hours'),
  quiet_end = ((now() at time zone 'Asia/Karachi')::time + interval '3 hours') where user_id = auth.uid() $$), 'ok',
  'and turns push on (quiet hours later today)');
select tests.clear_authentication();
select tests.authenticate_as((select fan_ur from cast_));
select pg_temp.state($$ insert into public.follows (user_id, brand_id) values (auth.uid(), pg_temp.id('brand')) $$) as f2 \gset
select pg_temp.state($$ select public.register_push_token('fan-ur-device-token-000000000001', 'android') $$) as t2 \gset
select pg_temp.state($$ update public.alert_prefs set push_enabled = true,
  quiet_start = ((now() at time zone 'Asia/Karachi')::time + interval '2 hours'),
  quiet_end = ((now() at time zone 'Asia/Karachi')::time + interval '3 hours') where user_id = auth.uid() $$) as p2 \gset
select tests.clear_authentication();

-- 4. The owner adds an outlet and writes a local deal as a draft, with a
--    target, a real discount and an image.
select tests.authenticate_as((select owner from cast_));
select is(pg_temp.state($$ insert into public.outlets (brand_id, city_id, area_id, name, address, location)
  values (pg_temp.id('brand'), pg_temp.id('karachi'), pg_temp.id('clifton'), 'Chai Corner Clifton',
          'Block 5, Clifton, Karachi', 'SRID=4326;POINT(67.0305 24.8140)') $$), 'ok', 'the owner adds an outlet');
select is(pg_temp.state($$ insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en,
  offer_kind, percent, price_pkr, original_price_pkr)
  values (pg_temp.id('brand'), pg_temp.id('cafes'), 'food_deal', 'local', 'draft', 'business',
          'Karak chai and paratha', 'percent_off', 45, 590, 1000) $$), '23514',
  'a fake percentage is refused');
select is(pg_temp.state($$ with x as (insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, title_ur,
    offer_kind, percent, price_pkr, original_price_pkr, ends_at)
  values (pg_temp.id('brand'), pg_temp.id('cafes'), 'food_deal', 'local', 'draft', 'business',
          'Karak chai and paratha', 'کڑک چائے اور پراٹھا', 'percent_off', 41, 590, 1000, now() + interval '7 days')
  returning id) insert into ids select 'deal', id from x $$), 'ok', 'the real 41% is accepted as a draft');
select is(pg_temp.state($$ insert into public.deal_targets (deal_id, city_id, area_id)
  values (pg_temp.id('deal'), pg_temp.id('karachi'), pg_temp.id('clifton')) $$), 'ok', 'targeted at Clifton');
select is(pg_temp.state(format($$ insert into storage.objects (bucket_id, name) values ('deal-images', %L) $$,
  pg_temp.id('biz') || '/' || pg_temp.id('deal') || '/hero.jpg')), 'ok', 'its image goes in the business''s folder');
select is(pg_temp.state(format($$ update public.deals set image_path = %L where id = pg_temp.id('deal') $$,
  pg_temp.id('biz') || '/' || pg_temp.id('deal') || '/hero.jpg')), 'ok', 'and is attached to the draft');

-- 5. Sent for review; the owner can't publish it.
select is(pg_temp.state($$ update public.deals set status = 'pending_review' where id = pg_temp.id('deal') $$), 'ok',
  'the owner sends it for review');
select is(pg_temp.state($$ update public.deals set status = 'published' where id = pg_temp.id('deal') $$), '42501',
  'but cannot publish it');
select is(pg_temp.state($$ update public.deals set title_en = 'Something else' where id = pg_temp.id('deal') $$), '42501',
  'or change it while in review');
select tests.clear_authentication();
select tests.authenticate_as_anon();
select is((select count(*) from public.feed(pg_temp.id('karachi')) where id = pg_temp.id('deal')), 0::bigint,
  'nobody sees it yet');
select tests.clear_authentication();

-- 6. A moderator publishes it.
select tests.staff((select moderator from cast_));
select is(pg_temp.state($$ update public.deals set status = 'published' where id = pg_temp.id('deal') $$), 'ok',
  'a moderator publishes it');
select tests.clear_authentication();
set constraints all immediate;

-- 7. Shoppers find it through every read API.
select tests.authenticate_as_anon();
select is((select count(*) from public.feed(pg_temp.id('karachi'), array[pg_temp.id('cafes')]) where id = pg_temp.id('deal')),
  1::bigint, 'it is in the Karachi cafes feed');
select is((select distance_m from public.nearby_deals(24.8141, 67.0306, 1000) where id = pg_temp.id('deal')) < 50, true,
  'and near the outlet, with its distance');
select is((select count(*) from public.search_deals('paratha', pg_temp.id('karachi')) where id = pg_temp.id('deal')),
  1::bigint, 'and in search');
select is((select count(*) from public.brand_deals('chai-corner', pg_temp.id('karachi')) where id = pg_temp.id('deal')), 1::bigint,
  'and on its brand page');
select is((select brand_is_verified from public.deal_cards where id = pg_temp.id('deal')), true,
  'the card shows the verified brand');
select tests.clear_authentication();
select tests.authenticate_as((select fan_en from cast_));
select is((select count(*) from public.feed(pg_temp.id('karachi'), null, true) where id = pg_temp.id('deal')), 1::bigint,
  'a follower sees it in their following feed');
select tests.clear_authentication();

-- 8. The planner alerts both followers once, in their language; the
--    dispatcher's SQL side claims and closes the pushes.
select is(private.plan_alerts(), 2, 'the planner queues two pushes');
select is((select title from public.notifications where user_id = (select fan_en from cast_) and deal_id = pg_temp.id('deal')),
  'Chai Corner: 41% off', 'the English alert names the brand and the offer');
select ok((select title from public.notifications where user_id = (select fan_ur from cast_) and deal_id = pg_temp.id('deal'))
  like '%رعایت%', 'the Urdu follower gets it in Urdu');
create temp table claimed as select * from private.claim_due_pushes(100);
select is((select count(*) from claimed), 2::bigint, 'the dispatcher claims one push per device');
select is(private.mark_pushes_sent(array(select outbox_id from claimed)), 2, 'and marks them sent');
select is(private.plan_alerts(), 0, 'nothing is alerted twice');

-- 9. A shopper reports it; freshness drops. A shopper's submission is
--    approved through the moderation RPC (Phase 3), notifying them.
select tests.authenticate_as((select fan_en from cast_));
select pg_temp.state($$ insert into public.reports (deal_id, reason) values (pg_temp.id('deal'), 'wrong_price') $$) as rep \gset
select pg_temp.state($$ with x as (insert into public.submissions (kind, brand_name, brand_id, title)
  values ('food_deal', 'Chai Corner', pg_temp.id('brand'), 'Free chai on Fridays') returning id) insert into ids select 'sub', id from x $$) as sub \gset
select tests.clear_authentication();
select private.refresh_freshness() as refreshed \gset
select is((select freshness from public.deals where id = pg_temp.id('deal')), 25::smallint,
  'never verified (40) minus one open report (15)');
select tests.staff((select moderator from cast_));
select is(pg_temp.state(format($$ select public.approve_submission(%L, %L::jsonb) $$, pg_temp.id('sub'),
  jsonb_build_object('brand_id', pg_temp.id('brand'), 'category_id', pg_temp.id('cafes'), 'kind', 'food_deal',
    'scope', 'nationwide', 'title_en', 'Free chai on Fridays', 'offer_kind', 'text', 'offer_text_en', 'Free chai'))),
  'ok', 'a moderator approves a shopper''s submission');
select tests.clear_authentication();
select is((select count(*) from public.notifications where user_id = (select fan_en from cast_) and kind = 'system'), 1::bigint,
  'the submitter hears it is live');

-- 10. It ends; the expiry job retires it from the lists, not from links.
update public.deals set starts_at = now() - interval '2 days', ends_at = now() - interval '1 minute'
  where id = pg_temp.id('deal');
select is(private.expire_deals() >= 1, true, 'the expiry job expires it');
select tests.authenticate_as_anon();
select is((select count(*) from public.feed(pg_temp.id('karachi')) where id = pg_temp.id('deal')), 0::bigint,
  'it leaves the feed');
select is((select status::text from public.deal_cards where id = pg_temp.id('deal')), 'expired',
  'but its link still opens, marked expired');
select tests.clear_authentication();

-- 11. The follower deletes their account: their data goes, the report stays.
delete from auth.users where id = (select fan_en from cast_);
select is((select count(*) from public.follows where user_id = (select fan_en from cast_))
          + (select count(*) from public.push_tokens where user_id = (select fan_en from cast_))
          + (select count(*) from public.notifications where user_id = (select fan_en from cast_)), 0::bigint,
  'account deletion removes their follows, devices and alerts');

select * from finish();
rollback;
