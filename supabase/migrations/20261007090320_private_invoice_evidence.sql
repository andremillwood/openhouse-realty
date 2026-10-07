-- Storage access remains closed until scoped reservation/certification RPCs are implemented.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('vendor-invoice-evidence','vendor-invoice-evidence',false,8388608,array['application/pdf','image/jpeg','image/png']) on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=excluded.allowed_mime_types;
create table public.vendor_invoice_evidence(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.reviewed_vendor_invoices(id),organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),request_id uuid not null,
 kind text not null check(kind in('invoice','supporting')),file_name text not null check(length(trim(file_name)) between 1 and 160 and file_name !~ E'[\\x00-\\x1f\\x7f/\\\\]'),mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),
 declared_size bigint not null check(declared_size between 1 and 8388608),object_path text not null unique,
 state text not null default 'reserved' check(state in('reserved','uploaded','withdrawn','expired')),sha256 text check(sha256 is null or sha256 ~ '^[a-f0-9]{64}$'),actual_size bigint check(actual_size is null or actual_size=declared_size),
 expires_at timestamptz not null default statement_timestamp()+interval '30 minutes',uploaded_at timestamptz,withdrawn_at timestamptz,purged_at timestamptz,created_at timestamptz not null default statement_timestamp(),unique(user_id,request_id),
 check(state<>'uploaded' or (sha256 is not null and actual_size is not null and uploaded_at is not null))
);
create index vendor_invoice_evidence_parent_idx on public.vendor_invoice_evidence(organization_id,invoice_id,state,created_at desc,id);
alter table public.vendor_invoice_evidence enable row level security;
revoke all on public.vendor_invoice_evidence from public,anon,authenticated,service_role;
grant select on public.vendor_invoice_evidence to authenticated,service_role;
create policy "invoice staff read uploaded source evidence" on public.vendor_invoice_evidence for select to authenticated using(organization_id=(select private.verified_invoice_organization()) and (state='uploaded' or user_id=(select auth.uid())));
create table public.vendor_invoice_evidence_events(
 id uuid primary key default gen_random_uuid(),evidence_id uuid not null references public.vendor_invoice_evidence(id),actor_user_id uuid not null references auth.users(id),event_name text not null check(event_name in('reserved','uploaded','withdrawn','expired')),created_at timestamptz not null default statement_timestamp()
);
create index vendor_invoice_evidence_events_parent_idx on public.vendor_invoice_evidence_events(evidence_id,created_at desc,id);
alter table public.vendor_invoice_evidence_events enable row level security;
revoke all on public.vendor_invoice_evidence_events from public,anon,authenticated,service_role;
grant select on public.vendor_invoice_evidence_events to authenticated,service_role;
create policy "read accessible invoice evidence history" on public.vendor_invoice_evidence_events for select to authenticated using(exists(select 1 from public.vendor_invoice_evidence e where e.id=evidence_id));
create trigger immutable_invoice_evidence_events before update or delete on public.vendor_invoice_evidence_events for each row execute function private.guard_finance_immutable();
create function private.guard_invoice_evidence_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if not exists(select 1 from public.reviewed_vendor_invoices i join auth.users u on u.id=i.submitted_by where i.id=new.invoice_id and i.organization_id=new.organization_id and i.submitted_by=new.user_id and i.state='submitted' and u.email_confirmed_at is not null) then raise exception 'Verified invoice submitter and organization binding required' using errcode='42501';end if;
 else
  if row(new.invoice_id,new.organization_id,new.user_id,new.request_id,new.kind,new.file_name,new.mime_type,new.declared_size,new.object_path,new.created_at,new.expires_at) is distinct from row(old.invoice_id,old.organization_id,old.user_id,old.request_id,old.kind,old.file_name,old.mime_type,old.declared_size,old.object_path,old.created_at,old.expires_at) then raise exception 'Invoice evidence identity is immutable' using errcode='23505';end if;
 end if;return new;
end $$;
revoke all on function private.guard_invoice_evidence_binding() from public,anon,authenticated,service_role;
create trigger guard_invoice_evidence_binding before insert or update on public.vendor_invoice_evidence for each row execute function private.guard_invoice_evidence_binding();
