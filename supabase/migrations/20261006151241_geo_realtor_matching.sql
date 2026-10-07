-- Only approved approximate coordinates belong in the public listing record.
alter table public.listings
  add column approximate_latitude double precision,
  add column approximate_longitude double precision,
  add column location_label text,
  add constraint listings_approximate_location_valid check (
    (approximate_latitude is null and approximate_longitude is null)
    or (approximate_latitude is not null and approximate_longitude is not null
      and approximate_latitude between -90 and 90
      and approximate_longitude between -180 and 180)
  );
comment on column public.listings.approximate_latitude is 'Approved neighborhood-level map point, never a private exact address.';
comment on column public.listings.approximate_longitude is 'Approved neighborhood-level map point, never a private exact address.';

create table public.realtor_profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  bio text not null default '',
  photo_url text,
  service_areas text[] not null default '{}',
  supported_intents text[] not null default '{}'
    check (supported_intents <@ array['buy','rent','sell']::text[]),
  communication_style text not null check (communication_style in ('thoughtful','direct','collaborative')),
  guidance_style text not null check (guidance_style in ('step-by-step','data-led','independent')),
  decision_pace text not null check (decision_pace in ('considered','decisive','flexible')),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.realtor_profiles enable row level security;
revoke all on public.realtor_profiles from anon, authenticated;
grant select on public.realtor_profiles to anon, authenticated;
create policy "published realtor profiles are public" on public.realtor_profiles
  for select to anon, authenticated using (is_published);
-- Profiles are curated by a trusted staff workflow; clients cannot publish themselves.

create table public.realtor_match_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  intent text not null check (intent in ('buy','rent','sell')),
  preferred_area text not null,
  communication_style text not null check (communication_style in ('thoughtful','direct','collaborative')),
  guidance_style text not null check (guidance_style in ('step-by-step','data-led','independent')),
  decision_pace text not null check (decision_pace in ('considered','decisive','flexible')),
  consented_at timestamptz not null default now()
);
alter table public.realtor_match_preferences enable row level security;
revoke all on public.realtor_match_preferences from anon, authenticated;
grant select, insert, update, delete on public.realtor_match_preferences to authenticated;
create policy "users manage their own matching preferences" on public.realtor_match_preferences
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
