-- Storage: buckets and who may write where (policies on storage.objects).
-- Size and MIME limits are enforced by the Storage API itself; here we
-- check the bucket settings that drive it.
begin;
select plan(23);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
create function pg_temp.up(bucket text, path text) returns text language sql as $$
  select format('insert into storage.objects (bucket_id, name) values (%L, %L)', bucket, path);
$$;
create function pg_temp.a(path text) returns text language sql as $$
  select replace(replace(replace(path, 'A', (select biz_a from w)::text), 'D', (select live_a from w)::text),
                 'B', (select biz_b from w)::text);
$$;
grant execute on function pg_temp.up(text, text), pg_temp.a(text) to anon, authenticated;

-- Buckets
select results_eq($$ select id, public, file_size_limit from storage.buckets order by id $$,
  $$ values ('avatars', false, 1048576::bigint), ('brand-logos', true, 1048576::bigint),
            ('deal-images', true, 2097152::bigint), ('submission-photos', false, 5242880::bigint) $$,
  'four buckets: public images, private avatars and submission photos, with size limits');
select is_empty($$ select id from storage.buckets
  where not (allowed_mime_types <@ array['image/jpeg', 'image/png', 'image/webp']) $$,
  'images only (no SVG) in every bucket');

-- Members of business A
select tests.authenticate_as((select owner from w));
select lives_ok(pg_temp.up('deal-images', pg_temp.a('A/D/photo.webp')),
  'an owner uploads an image for their deal');
select tests.authenticate_as((select editor from w));
select lives_ok(pg_temp.up('deal-images', pg_temp.a('A/D/photo-2.jpg')), 'so does an editor');
select is((select count(*)::int from storage.objects where bucket_id = 'deal-images'), 2,
  'members see their business''s files');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('B/') || (select live_b from w) || '/x.png'),
  '42501', null, 'not into another business''s folder');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/') || (select live_b from w) || '/x.png'),
  '42501', null, 'not for another business''s deal under their own folder');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/D/logo.svg')), '42501', null, 'no SVG');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/D/shell.php')), '42501', null, 'images only');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/D/../x.png')), '42501', null, 'no ..');
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/D/extra/x.png')), '42501', null, 'exactly two folders');
select throws_ok(pg_temp.up('deal-images', 'not-a-uuid/'' or 1=1/x.png'), '42501', null,
  'a hostile folder name is denied, not an error');
select throws_ok($$ update storage.objects set name = replace(name, (select biz_a from w)::text, (select biz_b from w)::text)
  where bucket_id = 'deal-images' $$, '42501', null, 'moving a file into another business''s folder fails');

-- Others
select tests.authenticate_as((select other_owner from w));
select is((select count(*)::int from storage.objects where bucket_id = 'deal-images'), 0,
  'another business sees none of A''s files');
select tests.authenticate_as((select shopper from w));
select throws_ok(pg_temp.up('deal-images', pg_temp.a('A/D/x.png')), '42501', null, 'a shopper cannot upload deal images');
select tests.authenticate_as_anon();
select is((select count(*)::int from storage.objects), 0, 'anon cannot list any bucket');

-- Staff need MFA.
select tests.authenticate_as((select moderator from w));
select throws_ok(pg_temp.up('deal-images', 'staff/' || (select live_b from w) || '/x.png'), '42501', null,
  'without MFA a moderator cannot upload');
select tests.staff((select moderator from w));
select lives_ok(pg_temp.up('deal-images', 'staff/' || (select live_b from w) || '/x.png'),
  'with MFA a moderator uploads to the staff folder');

-- Private files
select tests.authenticate_as((select shopper from w));
select lives_ok(pg_temp.up('avatars', (select shopper from w) || '/me.jpg'), 'a user uploads their avatar');
select throws_ok(pg_temp.up('avatars', (select owner from w) || '/me.jpg'), '42501', null,
  'not into someone else''s folder');
select tests.authenticate_as((select owner from w));
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'other users cannot read someone''s avatar');
select tests.staff((select moderator from w));
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 1,
  'moderators can review private files');

-- Upload quota: 60 files an hour.
select tests.clear_authentication();
insert into storage.objects (bucket_id, name, owner)
  select 'submission-photos', (select shopper from w) || '/p' || i || '.jpg', (select shopper from w)
  from generate_series(1, 60) i;
select tests.authenticate_as((select shopper from w));
select throws_ok(pg_temp.up('submission-photos', (select shopper from w) || '/one-more.jpg'), '42501', null,
  'the 61st upload in an hour is refused');

select * from finish();
rollback;
