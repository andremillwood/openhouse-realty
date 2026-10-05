-- Cross-domain operational primitives.
-- These tables are internal until role-aware staff/resident RLS is added in later migrations.

create table public.open_house_events (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer,
  status text not null default 'scheduled' check (
    status in ('scheduled', 'cancelled', 'completed')
  ),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.work_orders (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_id uuid references public.units(id) on delete set null,
  title text not null,
  description text,
  priority text not null default 'standard' check (
    priority in ('low', 'standard', 'high', 'urgent')
  ),
  status text not null default 'reported' check (
    status in ('reported', 'triaged', 'assigned', 'scheduled', 'on_site', 'in_progress', 'completed', 'closed', 'cancelled')
  ),
  assigned_vendor_name text,
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.worker_presence (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  work_order_id uuid references public.work_orders(id) on delete set null,
  person_name text not null,
  company_name text,
  destination_text text,
  authorization_note text,
  checked_in_at timestamptz not null default now(),
  checked_out_at timestamptz,
  check (checked_out_at is null or checked_out_at >= checked_in_at)
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid references public.properties(id) on delete set null,
  unit_id uuid references public.units(id) on delete set null,
  account_user_id uuid references auth.users(id) on delete set null,
  entry_type text not null check (
    entry_type in ('rent', 'maintenance_fee', 'late_fee', 'other_charge', 'credit', 'payment', 'deposit', 'refund', 'adjustment')
  ),
  amount_jmd numeric(14,2) not null,
  due_at timestamptz,
  posted_at timestamptz not null default now(),
  reference text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.cheque_payments (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid references public.ledger_entries(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  payer_name text not null,
  amount_jmd numeric(14,2) not null check (amount_jmd > 0),
  cheque_reference text not null,
  received_at timestamptz not null default now(),
  deposited_at timestamptz,
  cleared_at timestamptz,
  returned_at timestamptz,
  status text not null default 'received' check (
    status in ('received', 'awaiting_deposit', 'deposited', 'cleared', 'returned', 'cancelled')
  )
);

create table public.vendor_invoices (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.properties(id) on delete set null,
  work_order_id uuid references public.work_orders(id) on delete set null,
  vendor_name text not null,
  invoice_number text not null,
  amount_jmd numeric(14,2) not null check (amount_jmd >= 0),
  status text not null default 'submitted' check (
    status in ('submitted', 'under_review', 'approved', 'rejected', 'paid')
  ),
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  paid_at timestamptz
);

create table public.property_tax_obligations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  tax_type text not null,
  period_label text not null,
  amount_jmd numeric(14,2) not null check (amount_jmd >= 0),
  due_at timestamptz not null,
  status text not null default 'due' check (
    status in ('due', 'scheduled', 'paid', 'overdue', 'disputed')
  ),
  paid_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now()
);

create table public.financing_offers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_name text not null,
  amount_jmd numeric(14,2) not null check (amount_jmd > 0),
  rate_label text not null,
  fees_jmd numeric(14,2) not null default 0,
  term_months integer not null check (term_months > 0),
  periodic_payment_jmd numeric(14,2) not null check (periodic_payment_jmd > 0),
  total_repayment_jmd numeric(14,2) not null check (total_repayment_jmd >= amount_jmd),
  expires_at timestamptz,
  status text not null default 'offered' check (
    status in ('offered', 'viewed', 'accepted', 'declined', 'expired', 'provider_review', 'approved', 'rejected')
  ),
  provider_reference text,
  created_at timestamptz not null default now()
);

create table public.mobile_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  push_token text not null unique,
  app_version text,
  notifications_enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index work_orders_property_status_idx
  on public.work_orders(property_id, status, priority);

create index worker_presence_onsite_idx
  on public.worker_presence(property_id, checked_out_at, checked_in_at desc);

create index ledger_account_idx
  on public.ledger_entries(account_user_id, posted_at desc);

create index tax_due_idx
  on public.property_tax_obligations(property_id, due_at, status);

alter table public.open_house_events enable row level security;
alter table public.work_orders enable row level security;
alter table public.worker_presence enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.cheque_payments enable row level security;
alter table public.vendor_invoices enable row level security;
alter table public.property_tax_obligations enable row level security;
alter table public.financing_offers enable row level security;
alter table public.mobile_devices enable row level security;

-- Public users may discover scheduled open houses tied to published listings.
create policy "scheduled open houses for published listings are public"
on public.open_house_events for select
to anon, authenticated
using (
  status = 'scheduled'
  and exists (
    select 1 from public.listings
    where listings.id = open_house_events.listing_id
      and listings.status = 'published'
  )
);

-- A user may see financing offers addressed to them. Offers are written by trusted server/provider workflows.
create policy "users read own financing offers"
on public.financing_offers for select
to authenticated
using ((select auth.uid()) = user_id);

-- Users manage their own mobile device registrations.
create policy "users manage own mobile devices"
on public.mobile_devices for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select on public.open_house_events to anon, authenticated;
grant select on public.financing_offers to authenticated;
grant select, insert, update, delete on public.mobile_devices to authenticated;

-- Internal operational/financial tables remain unavailable to the Data API
-- until staff/resident role policies are introduced.
revoke all on public.work_orders from anon, authenticated;
revoke all on public.worker_presence from anon, authenticated;
revoke all on public.ledger_entries from anon, authenticated;
revoke all on public.cheque_payments from anon, authenticated;
revoke all on public.vendor_invoices from anon, authenticated;
revoke all on public.property_tax_obligations from anon, authenticated;
