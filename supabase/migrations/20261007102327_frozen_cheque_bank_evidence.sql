-- Each bank decision retains exactly the certified document it used.
-- Bank actions remain unavailable until the subsequent custody transition migration.
create table public.cheque_bank_evidence_snapshots(
 event_id uuid primary key references public.cheque_custody_events(id),
 cheque_id uuid not null references public.audited_cheque_receipts(id),
 evidence_id uuid not null unique references public.cheque_bank_evidence(id),
 organization_id uuid not null references public.organizations(id),
 decision_version integer not null check(decision_version>=2),
 kind text not null check(kind in('deposit','clearance','return')),
 file_name text not null,mime_type text not null,
 sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 actual_size bigint not null check(actual_size between 1 and 8388608),
 bank_reference text not null check(length(trim(bank_reference)) between 3 and 120 and bank_reference !~ '[[:cntrl:]]'),
 frozen_at timestamptz not null default statement_timestamp(),
 unique(cheque_id,decision_version)
);
create index cheque_bank_snapshot_scope_idx on public.cheque_bank_evidence_snapshots(organization_id,cheque_id,decision_version);
alter table public.cheque_bank_evidence_snapshots enable row level security;
revoke all on public.cheque_bank_evidence_snapshots from public,anon,authenticated,service_role;
grant select on public.cheque_bank_evidence_snapshots to authenticated,service_role;
create policy "verified finance reads organization bank snapshots" on public.cheque_bank_evidence_snapshots for select to authenticated using(organization_id=(select private.verified_finance_organization()));
create trigger immutable_cheque_bank_snapshots before update or delete on public.cheque_bank_evidence_snapshots for each row execute function private.guard_finance_immutable();

create function private.guard_cheque_bank_snapshot_binding() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(
  select 1 from public.cheque_custody_events v
  join public.audited_cheque_receipts c on c.id=v.cheque_id and c.organization_id=v.organization_id
  join public.cheque_bank_evidence e on e.cheque_id=c.id and e.organization_id=c.organization_id
  where v.id=new.event_id and c.id=new.cheque_id and c.organization_id=new.organization_id
   and v.version=new.decision_version and c.version=v.version and c.state=v.new_state
   and v.action=case new.kind when 'deposit' then 'record_deposit' when 'clearance' then 'confirm_clear' else 'record_return' end
   and v.payload->>'evidence_id'=new.evidence_id::text and v.payload->>'bank_reference'=new.bank_reference
   and e.id=new.evidence_id and e.state='uploaded' and e.purged_at is null
   and row(e.kind,e.file_name,e.mime_type,e.sha256,e.actual_size) is not distinct from row(new.kind,new.file_name,new.mime_type,new.sha256,new.actual_size)
 ) then raise exception 'Bank snapshot must match current audited decision and certified bytes' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_cheque_bank_snapshot_binding() from public,anon,authenticated,service_role;
create trigger guard_cheque_bank_snapshot_binding before insert on public.cheque_bank_evidence_snapshots for each row execute function private.guard_cheque_bank_snapshot_binding();

create function private.guard_frozen_cheque_bank_evidence() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.cheque_bank_evidence_snapshots where evidence_id=old.id) then
  raise exception 'Audited bank evidence is frozen' using errcode='23505';
 end if;
 if tg_op='UPDATE' and new.purged_at is distinct from old.purged_at and new.state not in('withdrawn','expired') then
  raise exception 'Current cheque evidence cannot be purged' using errcode='23505';
 end if;
 if tg_op='DELETE' then return old;end if;
 return new;
end $$;
revoke all on function private.guard_frozen_cheque_bank_evidence() from public,anon,authenticated,service_role;
create trigger guard_frozen_cheque_bank_evidence before update or delete on public.cheque_bank_evidence for each row execute function private.guard_frozen_cheque_bank_evidence();
