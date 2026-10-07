-- Staff membership is provisioned by an administrator, never by signup metadata.
create table public.staff_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'realtor', 'manager', 'finance')),
  created_at timestamptz not null default now()
);
alter table public.staff_accounts enable row level security;
revoke all on public.staff_accounts from anon, authenticated;
grant select on public.staff_accounts to authenticated;
create policy "staff read own membership" on public.staff_accounts for select to authenticated
using (user_id = (select auth.uid()));

create table public.saved_listings (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);
create index saved_listings_listing_idx on public.saved_listings(listing_id);
alter table public.saved_listings enable row level security;
revoke all on public.saved_listings from anon, authenticated;
grant select, insert, delete on public.saved_listings to authenticated;
create policy "users read own saved listings" on public.saved_listings for select to authenticated
using (user_id = (select auth.uid()));
create policy "users save published listings" on public.saved_listings for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.listings where id = listing_id and status = 'published'
));
create policy "users remove own saved listings" on public.saved_listings for delete to authenticated
using (user_id = (select auth.uid()));
create policy "users create own profile" on public.profiles for insert to authenticated
with check (id = (select auth.uid()));

-- Prospect status changes require a future controlled workflow.
revoke update on public.viewings from authenticated;
drop policy "users update own requested viewings" on public.viewings;
drop policy "users create own viewings" on public.viewings;
create policy "users request published viewings" on public.viewings for insert to authenticated
with check (
  user_id = (select auth.uid()) and status = 'requested'
  and requested_for > now() and requested_for < now() + interval '120 days'
  and exists (select 1 from public.listings where id = listing_id and status = 'published')
);
