-- OpenHouse marketplace foundation
-- Safe-by-default: exposed tables use RLS and explicit Data API grants.

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  area text,
  address_text text,
  created_at timestamptz not null default now()
);

create table public.units (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_label text not null,
  bedrooms numeric(3,1) not null default 0,
  bathrooms numeric(3,1) not null default 0,
  parking_spaces integer not null default 0,
  floor integer,
  size_sq_ft integer,
  created_at timestamptz not null default now(),
  unique(property_id, unit_label)
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.properties(id) on delete set null,
  unit_id uuid references public.units(id) on delete set null,
  title text not null,
  area text not null,
  intent text not null check (intent in ('sale', 'rent')),
  property_type text not null check (property_type in ('apartment', 'townhouse', 'house', 'land', 'commercial')),
  status text not null default 'draft' check (status in ('draft', 'published', 'paused', 'under_offer', 'leased', 'sold', 'withdrawn')),
  price_jmd numeric(14,2) not null check (price_jmd >= 0),
  bedrooms numeric(3,1) not null default 0,
  bathrooms numeric(3,1) not null default 0,
  parking_spaces integer not null default 0,
  floor integer,
  size_sq_ft integer,
  balcony boolean not null default false,
  furnished boolean not null default false,
  modern_interior boolean not null default false,
  description text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.preference_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  max_price_jmd numeric(14,2),
  min_bedrooms numeric(3,1),
  min_parking_spaces integer,
  preferred_areas text[] not null default '{}',
  preferred_features text[] not null default '{}',
  avoided_features text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.preference_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  signal_type text not null check (signal_type in ('explicit', 'inferred', 'behavioral')),
  key text not null,
  value jsonb not null,
  strength numeric(5,2) not null default 1,
  user_confirmed boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.listing_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  anonymous_session_id text,
  listing_id uuid not null references public.listings(id) on delete cascade,
  interaction_type text not null check (
    interaction_type in ('view', 'save', 'hide', 'share', 'enquire', 'viewing_request')
  ),
  reason text,
  created_at timestamptz not null default now(),
  check (user_id is not null or anonymous_session_id is not null)
);

create table public.viewings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  requested_for timestamptz not null,
  status text not null default 'requested' check (
    status in ('requested', 'confirmed', 'completed', 'cancelled', 'no_show')
  ),
  created_at timestamptz not null default now()
);

create table public.seller_leads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  name text,
  email text,
  phone text,
  property_address text not null,
  seller_intent text not null check (
    seller_intent in ('curious', 'considering', 'soon', 'already_listed')
  ),
  status text not null default 'new' check (
    status in ('new', 'contacted', 'market_review', 'proposal', 'listed', 'closed', 'lost')
  ),
  created_at timestamptz not null default now()
);

create table public.domain_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  aggregate_type text not null,
  aggregate_id uuid,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index listings_marketplace_idx
  on public.listings(status, intent, area, price_jmd);

create index listing_interactions_user_idx
  on public.listing_interactions(user_id, created_at desc);

create index preference_signals_user_idx
  on public.preference_signals(user_id, created_at desc);

create index domain_events_aggregate_idx
  on public.domain_events(aggregate_type, aggregate_id, created_at desc);

alter table public.organizations enable row level security;
alter table public.properties enable row level security;
alter table public.units enable row level security;
alter table public.listings enable row level security;
alter table public.profiles enable row level security;
alter table public.preference_profiles enable row level security;
alter table public.preference_signals enable row level security;
alter table public.listing_interactions enable row level security;
alter table public.viewings enable row level security;
alter table public.seller_leads enable row level security;
alter table public.domain_events enable row level security;

-- Public marketplace inventory.
create policy "published listings are public"
on public.listings for select
to anon, authenticated
using (status = 'published');

-- Users control their own identity/preferences/interactions.
create policy "users read own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

create policy "users update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "users read own preference profile"
on public.preference_profiles for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users insert own preference profile"
on public.preference_profiles for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "users update own preference profile"
on public.preference_profiles for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users manage own preference signals"
on public.preference_signals for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users read own listing interactions"
on public.listing_interactions for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users create own listing interactions"
on public.listing_interactions for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "users read own viewings"
on public.viewings for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users create own viewings"
on public.viewings for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "users update own requested viewings"
on public.viewings for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Seller intake is write-only from the public surface.
create policy "public can create seller leads"
on public.seller_leads for insert
to anon, authenticated
with check (true);

-- Explicit Data API grants for new Supabase projects.
grant usage on schema public to anon, authenticated;
grant select on public.listings to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.preference_profiles to authenticated;
grant select, insert, update, delete on public.preference_signals to authenticated;
grant select, insert on public.listing_interactions to authenticated;
grant select, insert, update on public.viewings to authenticated;
grant insert on public.seller_leads to anon, authenticated;

-- Internal tables remain inaccessible through the Data API until staff RLS is added.
revoke all on public.organizations from anon, authenticated;
revoke all on public.properties from anon, authenticated;
revoke all on public.units from anon, authenticated;
revoke all on public.domain_events from anon, authenticated;
