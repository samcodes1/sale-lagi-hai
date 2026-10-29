-- Storage (sub-phase 2.4): buckets, size and type limits, and who may
-- write where.
--
-- | Bucket            | Public | Limit | Path                                  | Write                         |
-- |-------------------|--------|-------|---------------------------------------|-------------------------------|
-- | deal-images       | yes    | 2 MB  | <business_id or staff>/<deal_id>/<file> | the business's members; staff |
-- | brand-logos       | yes    | 1 MB  | <business_id or staff>/<brand_id>/<file> | the business's members; staff |
-- | avatars           | no     | 1 MB  | <user_id>/<file>                      | the user                      |
-- | submission-photos | no     | 5 MB  | <user_id>/<file>                      | the user; moderators read     |
--
-- - Public buckets serve files by URL without a policy, so they hold public
--   images only. Nobody (not even anon) can *list* them: there is no anon
--   select policy.
-- - Images only: JPEG, PNG and WebP. No SVG (it can carry scripts). The
--   Storage API checks the MIME type and size; policies also check the
--   file extension and the folder layout.
-- - Folder names are compared as text, never cast: a hostile folder name
--   must fail the check, not raise an error.
-- - Resized variants come from Supabase image transformations at read time
--   (`/render/image/...?width=`), so only originals are stored.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('deal-images', 'deal-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('brand-logos', 'brand-logos', true, 1048576, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png', 'image/webp']),
  ('submission-photos', 'submission-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- An image file name: letters, digits, dot, dash and underscore, ending in
-- an allowed extension. Folder segments are checked by the callers.
create function private.is_image_name(name text) returns boolean
language sql immutable set search_path = '' as $$
  select name ~ '^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*/[A-Za-z0-9_.-]{1,100}$'
     and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
     and name !~ '\.\.';
$$;

-- May the caller write `<owner>/<item>/<file>` in deal-images (kind
-- 'deal') or brand-logos (kind 'brand')? Members write in their business's
-- folder, for that business's own deals or brands; staff (with MFA) also
-- write in `staff/` and in any business folder.
create function private.can_write_media(kind text, path text) returns boolean
language sql stable security definer set search_path = '' as $$
  with p as (select storage.foldername(path) as folders)
  select private.is_image_name(path)
     and array_length(p.folders, 1) = 2
     and (
       (private.is_moderator() and (
          p.folders[1] = 'staff'
          or p.folders[1] in (select b.id::text from public.businesses b)))
       or (
         p.folders[1] in (select id::text from private.my_active_business_ids() id)
         and case kind
           when 'deal' then p.folders[2] in (
             select d.id::text from public.deals d
             join public.brands br on br.id = d.brand_id
             where br.business_id::text = p.folders[1])
           when 'brand' then p.folders[2] in (
             select br.id::text from public.brands br
             where br.business_id::text = p.folders[1])
           else false
         end))
  from p;
$$;

-- Files the caller uploaded in the last hour, across all buckets.
create function private.my_recent_uploads() returns bigint
language sql stable security definer set search_path = '' as $$
  select count(*) from storage.objects o
  where o.owner = (select auth.uid()) and o.created_at > now() - interval '1 hour';
$$;

revoke execute on function private.is_image_name(text), private.can_write_media(text, text),
  private.my_recent_uploads() from public;
grant execute on function private.is_image_name(text), private.can_write_media(text, text),
  private.my_recent_uploads() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- deal-images and brand-logos (public read by URL; no listing for anon)
-- ---------------------------------------------------------------------------
create policy "media: members and staff upload" on storage.objects
  for insert to authenticated
  with check (
    ((bucket_id = 'deal-images' and (select private.can_write_media('deal', name)))
     or (bucket_id = 'brand-logos' and (select private.can_write_media('brand', name))))
    and (select private.my_recent_uploads()) < 60);

-- Upserts and the business portal's file list need select on their own files.
create policy "media: members and staff see their files" on storage.objects
  for select to authenticated
  using (
    (bucket_id = 'deal-images' and (select private.can_write_media('deal', name)))
    or (bucket_id = 'brand-logos' and (select private.can_write_media('brand', name))));

create policy "media: members and staff replace" on storage.objects
  for update to authenticated
  using (
    (bucket_id = 'deal-images' and (select private.can_write_media('deal', name)))
    or (bucket_id = 'brand-logos' and (select private.can_write_media('brand', name))))
  with check (
    (bucket_id = 'deal-images' and (select private.can_write_media('deal', name)))
    or (bucket_id = 'brand-logos' and (select private.can_write_media('brand', name))));

create policy "media: members and staff delete" on storage.objects
  for delete to authenticated
  using (
    (bucket_id = 'deal-images' and (select private.can_write_media('deal', name)))
    or (bucket_id = 'brand-logos' and (select private.can_write_media('brand', name))));

-- ---------------------------------------------------------------------------
-- avatars and submission-photos (private): <user_id>/<file>
-- ---------------------------------------------------------------------------
create policy "own files: upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('avatars', 'submission-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
    and (select private.is_image_name(name))
    and (select private.my_recent_uploads()) < 60);

create policy "own files: read" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('avatars', 'submission-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "own files: replace" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('avatars', 'submission-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (
    bucket_id in ('avatars', 'submission-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select private.is_image_name(name)));

create policy "own files: delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('avatars', 'submission-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Moderators review submission photos and avatars (reports of abuse).
create policy "staff: read private files" on storage.objects
  for select to authenticated
  using (bucket_id in ('avatars', 'submission-photos') and (select private.is_moderator()));
create policy "staff: remove private files" on storage.objects
  for delete to authenticated
  using (bucket_id in ('avatars', 'submission-photos') and (select private.is_moderator()));
