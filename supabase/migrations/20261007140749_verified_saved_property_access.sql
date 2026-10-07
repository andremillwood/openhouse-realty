create function private.verified_saved_property_user() returns uuid
language sql stable security definer set search_path='' as $$
 select id from auth.users where id=auth.uid() and email_confirmed_at is not null;
$$;
revoke all on function private.verified_saved_property_user() from public,anon,authenticated,service_role;
grant execute on function private.verified_saved_property_user() to authenticated;
alter policy "users read own saved listings" on public.saved_listings
 using(user_id=(select private.verified_saved_property_user()));
alter policy "users save published listings" on public.saved_listings
 with check(user_id=(select private.verified_saved_property_user()) and exists(
  select 1 from public.listings where id=listing_id and status='published'
 ));
alter policy "users remove own saved listings" on public.saved_listings
 using(user_id=(select private.verified_saved_property_user()));
