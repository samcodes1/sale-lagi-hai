-- Access: shopper data, reports, submissions, placements, payments, audit.
begin;
select plan(34);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
insert into public.notifications (user_id, kind, title) select shopper, 'system', 'Welcome' from w;
insert into public.payments (business_id, amount_pkr, provider, provider_ref, status, paid_at)
select biz_a, 5000, 'jazzcash', 'T1000', 'paid', now() from w;
insert into public.placements (business_id, deal_id, slot, starts_at, ends_at, status)
select biz_b, live_b, 'home_featured', now() - interval '1 day', now() + interval '6 days', 'active' from w;
create temp table bank as select tests.make_card_product(tests.make_bank()) as card;
grant select on bank to authenticated;

-- Shopper data is private.
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.follows (user_id, brand_id) select shopper, brand_a from w $$,
  'a shopper follows a brand');
select throws_ok($$ insert into public.follows (user_id, brand_id) select owner, brand_a from w $$,
  '42501', null, 'nobody follows on someone else''s behalf');
select lives_ok($$ insert into public.saves (user_id, deal_id) select shopper, live_a from w $$,
  'a shopper saves a live deal');
select throws_ok($$ insert into public.saves (user_id, deal_id) select shopper, draft_a from w $$,
  '42501', null, 'drafts cannot be saved (or probed by id)');
select lives_ok($$ insert into public.user_cards (user_id, card_product_id) select (select shopper from w), card from bank $$,
  'a shopper adds a card product');
select lives_ok($$ update public.alert_prefs set push_enabled = true where user_id = (select shopper from w) $$,
  'a shopper turns alerts on');
select throws_ok($$ update public.alert_prefs set user_id = (select owner from w) $$,
  '42501', null, 'alert prefs cannot be moved to another user');
select throws_ok($$ insert into public.notifications (user_id, kind, title) select shopper, 'system', 'Spam' from w $$,
  '42501', null, 'users cannot create notifications');
select lives_ok($$ update public.notifications set read_at = now() where user_id = (select shopper from w) $$,
  'a shopper marks a notification read');
select throws_ok($$ update public.notifications set title = 'Changed' $$,
  '42501', null, 'notification text is not editable');

select tests.authenticate_as((select owner from w));
select is((select count(*)::int from public.follows) + (select count(*)::int from public.saves)
        + (select count(*)::int from public.user_cards) + (select count(*)::int from public.notifications), 0,
  'another user sees none of it');
select tests.staff((select admin from w));
select is((select count(*)::int from public.follows) + (select count(*)::int from public.saves), 0,
  'not even an admin reads shoppers'' follows and saves');
select tests.authenticate_as_anon();
select throws_ok('select * from public.saves', '42501', null, 'anon cannot read saves');

-- Reports
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.reports (deal_id, reason) select live_a, 'expired' from w $$,
  'a shopper reports a live deal');
select throws_ok($$ insert into public.reports (deal_id, reason) select draft_a, 'expired' from w $$,
  '42501', null, 'unseen deals cannot be reported');
select throws_ok($$ insert into public.reports (deal_id, reason, status, resolved_at)
  select live_b, 'expired', 'resolved', now() from w $$, '42501', null,
  'a report cannot arrive resolved');
select tests.authenticate_as((select owner from w));
select is((select count(*)::int from public.reports), 0, 'reports are private to their sender');
select tests.staff((select moderator from w));
select is((select count(*)::int from public.reports), 1, 'moderators see reports');
select throws_ok($$ update public.reports set status = 'resolved', resolved_at = now(), resolved_by = (select admin from w) $$,
  '42501', null, 'a moderator resolves as themselves only');
select lives_ok($$ update public.reports set status = 'resolved', resolved_at = now(), resolved_by = (select moderator from w) $$,
  'a moderator resolves a report');

-- Submissions
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.submissions (kind, brand_name, title)
  values ('food_deal', 'Student Biryani', 'Two plates for Rs 600') $$, 'a shopper submits a deal');
select throws_ok($$ insert into public.submissions (kind, brand_name, title, status, reviewed_at)
  values ('food_deal', 'Student Biryani', 'Two plates for Rs 600', 'approved', now()) $$,
  '42501', null, 'a submission cannot approve itself');
select tests.staff((select moderator from w));
select lives_ok($$ update public.submissions set status = 'rejected', reviewed_at = now(),
  reviewer_id = (select moderator from w), reject_reason = 'Not a real offer' $$, 'a moderator reviews it');

-- Placements
select tests.authenticate_as_anon();
select is((select count(*)::int from public.placements), 1, 'anon sees live placements');
select tests.authenticate_as((select owner from w));
select lives_ok($$ insert into public.placements (business_id, deal_id, slot, starts_at, ends_at)
  select biz_a, live_a, 'home_featured', now(), now() + interval '7 days' from w $$,
  'an owner drafts a placement');
select throws_ok($$ insert into public.placements (business_id, deal_id, slot, starts_at, ends_at, status)
  select biz_a, live_a, 'home_featured', now(), now() + interval '7 days', 'active' from w $$,
  '42501', null, 'a business cannot activate a placement itself');
select throws_ok($$ update public.placements set priority = 100 where business_id = (select biz_a from w) $$,
  '42501', null, 'a business cannot raise its own priority');
select tests.authenticate_as((select other_owner from w));
select is((select count(*)::int from public.placements where business_id = (select biz_a from w)), 0,
  'other businesses do not see draft placements');
select tests.staff((select admin from w));
select lives_ok($$ update public.placements set status = 'active', priority = 10 where business_id = (select biz_a from w) $$,
  'an admin activates a placement');

-- Payments and audit
select tests.authenticate_as((select owner from w));
select is((select count(*)::int from public.payments), 1, 'owners see their payments');
select throws_ok($$ insert into public.payments (business_id, amount_pkr, provider) select biz_a, 1, 'manual' from w $$,
  '42501', null, 'nobody records a payment from the app');
select tests.authenticate_as((select editor from w));
select is((select count(*)::int from public.payments), 0, 'editors do not see payments');
select tests.staff((select moderator from w));
select is((select count(*)::int from public.audit_log), 0, 'moderators do not read the audit log');
select tests.staff((select admin from w));
select ok((select count(*) from public.audit_log) > 0, 'admins read the audit log');

select * from finish();
rollback;
