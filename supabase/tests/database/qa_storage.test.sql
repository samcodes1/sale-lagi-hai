-- QA (sub-phase 2.4): upload abuse against the storage policies. TODO
-- assertions are S4 findings in docs/qa/2.4.md.
begin;
select plan(8);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

-- Tries an upload as the current role; true when the policies allow it.
create function pg_temp.can_upload(bucket text, path text) returns boolean language plpgsql as $$
begin
  insert into storage.objects (bucket_id, name) values (bucket, path);
  return true;
exception when insufficient_privilege then
  return false;
end $$;
grant execute on function pg_temp.can_upload(text, text) to anon, authenticated;

create temp table names (label text, bucket text, path text);
grant select on names to anon, authenticated;
insert into names
select 'hostile', 'deal-images', f.p from w, lateral (values
  (biz_a || '/' || draft_a || '/a.jpg.php'),
  (biz_a || '/' || draft_a || '/x.svg'),
  (biz_a || '/' || draft_a || '/x.gif'),
  (biz_a || '/' || draft_a || '/..jpg'),
  (biz_a || '/' || draft_a || '/x.jpeg%00.php'),
  (biz_a || '/' || draft_a || '/extra/deep.jpg'),
  (biz_a || '/../' || biz_b || '/x.jpg'),
  ('/' || biz_a || '/' || draft_a || '/x.jpg'),
  (biz_a || '//' || draft_a || '/x.jpg'),
  (upper(biz_a::text) || '/' || draft_a || '/x.jpg'),
  (biz_a || '/' || live_b || '/other-business-deal.jpg'),
  (biz_b || '/' || live_b || '/cross-business.jpg'),
  ('staff/' || draft_a || '/not-staff.jpg'),
  ('''; select 1; --/' || draft_a || '/x.jpg'),
  (biz_a || '/' || brand_a || '/brand-id-in-deal-bucket.jpg')
) f(p)
union all
select 'hostile', 'avatars', f.p from w, lateral (values
  (shopper || '/someone-else.png'),
  (editor || '/sub/folder.png'),
  (editor || E'/new\nline.png'),
  (editor || '/x.svg')
) f(p)
union all
select 'fine', 'deal-images', biz_a || '/' || draft_a || '/' || f from w,
  unnest(array['ok.jpg', 'OK.JPG', 'a.php.jpg', 'x.webp', 'x.png']) f
union all
select 'fine', 'brand-logos', biz_a || '/' || brand_a || '/logo.png' from w
union all
select 'fine', 'avatars', editor || '/me.png' from w;

select tests.authenticate_as((select editor from w));
select is((select count(*) from names where label = 'hostile' and pg_temp.can_upload(bucket, path)), 0::bigint,
  'no hostile name, foreign folder or wrong extension is accepted');
select is((select count(*) from names where label = 'fine' and pg_temp.can_upload(bucket, path)),
  (select count(*) from names where label = 'fine'), 'every well-formed upload by a member is accepted');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select is((select count(*) from names where pg_temp.can_upload(bucket, path)), 0::bigint, 'anon uploads nothing');
select is((select count(*) from storage.objects), 0::bigint, 'anon lists nothing, not even public buckets');
select tests.clear_authentication();

select tests.authenticate_as((select shopper from w));
select is((select count(*) from storage.objects), 0::bigint, 'a shopper lists none of the business''s or editor''s files');
select is(tests.affected($$ delete from storage.objects returning 1 $$), 0, 'or deletes them');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- S4 findings (TODO).
-- ---------------------------------------------------------------------------
select todo('QA 2.4-S1 (S4): an update may move a file across buckets (5 MB submission photo into public deal-images)', 1);
select tests.authenticate_as((select editor from w));
insert into storage.objects (bucket_id, name) select 'submission-photos', editor || '/big.jpg' from w;
select is(tests.affected(format($$ update storage.objects set bucket_id = 'deal-images', name = %L
  where bucket_id = 'submission-photos' and name = %L returning 1 $$,
  (select biz_a || '/' || draft_a || '/moved.jpg' from w), (select editor || '/big.jpg' from w))), 0,
  'a file cannot change bucket');
select tests.clear_authentication();

select todo('QA 2.4-S2 (S4): the hourly quota counts files that still exist, so delete-and-reupload is unlimited', 1);
select tests.authenticate_as((select shopper from w));
insert into storage.objects (bucket_id, name) select 'avatars', shopper || '/a' || g || '.jpg' from w, generate_series(1, 59) g;
delete from storage.objects;
select is(pg_temp.can_upload('avatars', (select shopper from w) || '/after-delete.jpg'), false,
  'the 60th upload in an hour is refused even after deleting earlier ones');
select tests.clear_authentication();

select * from finish();
rollback;
