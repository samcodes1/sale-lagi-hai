begin;
select plan(16);

create temp table f as
  select tests.create_user() as reporter, tests.make_deal() as deal,
         tests.make_business() as business;

-- Reports
select lives_ok($$
  insert into public.reports (deal_id, reporter_id, reason) select deal, reporter, 'expired' from f
$$, 'report a deal');
select throws_ok($$
  insert into public.reports (deal_id, reporter_id, reason) select deal, reporter, 'closed' from f
$$, '23505', null, 'one report per user per deal');
select throws_ok($$
  insert into public.reports (deal_id, reporter_id, reason) select deal, tests.create_user(), 'other' from f
$$, '23514', null, '"other" needs a note');
select throws_ok($$
  update public.reports set status = 'resolved' where reporter_id = (select reporter from f)
$$, '23514', null, 'resolving a report records when');
delete from auth.users where id = (select reporter from f);
select is((select reporter_id from public.reports where deal_id = (select deal from f)), null,
  'a report stays when the reporter deletes their account, without their id');

-- Submissions
select throws_ok($$
  insert into public.submissions (kind, brand_name, title, status, reviewed_at)
  values ('food_deal', 'Kolachi', 'BBQ platter deal', 'rejected', now())
$$, '23514', null, 'a rejection needs a reason');
select throws_ok($$
  insert into public.submissions (kind, brand_name, title, status)
  values ('food_deal', 'Kolachi', 'BBQ platter deal', 'approved')
$$, '23514', null, 'a reviewed submission records when');
select throws_ok($$
  insert into public.submissions (kind, brand_name, title, status, reviewed_at)
  values ('food_deal', 'Kolachi', 'BBQ platter deal', 'duplicate', now())
$$, '23514', null, 'a duplicate points to the existing deal');

-- Placements promote the business's own deals only.
create temp table own as
  select b.business, tests.make_deal(tests.make_brand(b.business)) as deal from f b;
select lives_ok($$
  insert into public.placements (business_id, deal_id, slot, starts_at, ends_at)
  select business, deal, 'home_featured', now(), now() + interval '7 days' from own
$$, 'a business promotes its own deal');
select throws_ok($$
  insert into public.placements (business_id, deal_id, slot, starts_at, ends_at)
  select business, tests.make_deal(), 'home_featured', now(), now() + interval '7 days' from own
$$, '23514', null, 'a business cannot promote someone else''s deal');
select throws_ok($$
  insert into public.placements (business_id, deal_id, slot, starts_at, ends_at)
  select business, deal, 'home_featured', now(), now() + interval '120 days' from own
$$, '23514', null, 'placements run at most 90 days');
select throws_ok($$
  insert into public.placements (business_id, deal_id, slot, starts_at, ends_at)
  select business, deal, 'category_top', now(), now() + interval '7 days' from own
$$, '23514', null, 'a category placement names the category');

-- Payments
select throws_ok($$
  insert into public.payments (business_id, amount_pkr, provider, status)
  select business, 5000, 'jazzcash', 'paid' from f
$$, '23514', null, 'a paid payment records when, and its transaction id');
insert into public.payments (business_id, amount_pkr, provider, provider_ref, status, paid_at)
select business, 5000, 'jazzcash', 'T123456', 'paid', now() from f;
select throws_ok($$
  insert into public.payments (business_id, amount_pkr, provider, provider_ref, status, paid_at)
  select business, 5000, 'jazzcash', 'T123456', 'paid', now() from f
$$, '23505', null, 'a provider transaction is recorded once');

-- Audit log
create temp table admin as select tests.create_user() as id;
insert into public.user_roles (user_id, role) select id, 'moderator' from admin;
select is((select count(*)::int from public.audit_log
           where table_name = 'user_roles' and row_id like '%' || (select id from admin) || '%'), 1,
  'granting a role is audited');
update public.deals set title_en = 'New title' where id = (select deal from own);
update public.deals set status = 'published' where id = (select deal from own);
select is((select count(*)::int from public.audit_log
           where table_name = 'deals' and row_id = (select deal from own)::text), 1,
  'deal status changes are audited, other edits are not');

select * from finish();
rollback;
