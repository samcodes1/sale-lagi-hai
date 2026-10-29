-- Accounts (sub-phase 4.2): moving a guest's choices into their account,
-- and account deletion.
--
-- The app is guest-first: city, language and followed brands live on the
-- phone until the shopper signs in. Then one call copies them into the
-- account, under the shopper's own RLS.
--
-- Account deletion (a Play requirement) runs in the delete-account Edge
-- Function: it checks a fresh sign-in, removes the user's private files
-- through the Storage API (Supabase refuses to delete a user who still
-- owns objects), then deletes the auth user. `on delete cascade` removes
-- the rest: profile, roles, follows, saves, cards, alert preferences,
-- notifications, push tokens and queued pushes.

-- Copies a guest's choices into the signed-in account. Existing account
-- values win only where the guest chose nothing (null city, null
-- language). Brands are followed only if the caller can see them (active
-- brands, by RLS); following twice is a no-op.
create function public.sync_guest_preferences(
  city uuid default null,
  lang text default null,
  brand_ids uuid[] default '{}'
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if coalesce(cardinality(brand_ids), 0) > 200 then
    raise exception 'at most 200 brands at once' using errcode = '22023';
  end if;
  update public.profiles p
  set home_city_id = coalesce(sync_guest_preferences.city, p.home_city_id),
      locale = coalesce(sync_guest_preferences.lang, p.locale)
  where p.id = (select auth.uid());
  insert into public.follows (user_id, brand_id)
  select (select auth.uid()), b.id
  from public.brands b
  where b.id = any(coalesce(sync_guest_preferences.brand_ids, '{}'))
  on conflict do nothing;
end $$;
revoke execute on function public.sync_guest_preferences(uuid, text, uuid[]) from public, anon;
grant execute on function public.sync_guest_preferences(uuid, text, uuid[]) to authenticated;

-- For the delete-account Edge Function only (service role). Hands the
-- person's uploads in the public business buckets over to the business
-- (they stay: a deal keeps its picture), and returns the private files
-- (avatars, submission photos) to delete through the Storage API.
create function public.prepare_account_deletion(target uuid)
returns table (bucket_id text, name text)
language plpgsql volatile security definer set search_path = '' as $$
begin
  update storage.objects o set owner = null, owner_id = null
  where o.owner_id = target::text and o.bucket_id in ('deal-images', 'brand-logos');
  return query
    select o.bucket_id, o.name from storage.objects o
    where o.owner_id = target::text
    order by o.bucket_id, o.name;
end $$;
revoke execute on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;
