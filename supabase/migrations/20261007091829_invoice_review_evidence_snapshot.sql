create table public.vendor_invoice_review_evidence(
 invoice_id uuid not null references public.reviewed_vendor_invoices(id),evidence_id uuid not null references public.vendor_invoice_evidence(id),organization_id uuid not null references public.organizations(id),
 reviewed_version integer not null check(reviewed_version>=2),kind text not null check(kind in('invoice','supporting')),file_name text not null,mime_type text not null,
 sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),actual_size bigint not null check(actual_size between 1 and 8388608),frozen_at timestamptz not null default statement_timestamp(),
 primary key(invoice_id,evidence_id),unique(evidence_id)
);
create index vendor_invoice_review_evidence_scope_idx on public.vendor_invoice_review_evidence(organization_id,invoice_id,reviewed_version);
alter table public.vendor_invoice_review_evidence enable row level security;
revoke all on public.vendor_invoice_review_evidence from public,anon,authenticated,service_role;
grant select on public.vendor_invoice_review_evidence to authenticated,service_role;
create policy "invoice staff read organization review evidence" on public.vendor_invoice_review_evidence for select to authenticated using(organization_id=(select private.verified_invoice_organization()));
create trigger immutable_invoice_review_evidence before update or delete on public.vendor_invoice_review_evidence for each row execute function private.guard_finance_immutable();

create function private.guard_invoice_review_evidence_binding() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.reviewed_vendor_invoices i join public.vendor_invoice_evidence e on e.invoice_id=i.id and e.organization_id=i.organization_id and e.user_id=i.submitted_by
  where i.id=new.invoice_id and i.organization_id=new.organization_id and i.state='submitted' and i.version+1=new.reviewed_version and e.id=new.evidence_id and e.state='uploaded'
  and row(e.kind,e.file_name,e.mime_type,e.sha256,e.actual_size) is not distinct from row(new.kind,new.file_name,new.mime_type,new.sha256,new.actual_size)) then
  raise exception 'Review snapshot must match certified invoice evidence and revision' using errcode='23505';
 end if;return new;
end $$;
revoke all on function private.guard_invoice_review_evidence_binding() from public,anon,authenticated,service_role;
create trigger guard_invoice_review_evidence_binding before insert on public.vendor_invoice_review_evidence for each row execute function private.guard_invoice_review_evidence_binding();

create function private.freeze_invoice_review_evidence() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.state='submitted' and new.state='under_review' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(old.organization_id::text,119));
  if not exists(select 1 from public.vendor_invoice_evidence where invoice_id=old.id and organization_id=old.organization_id and user_id=old.submitted_by and state='uploaded' and kind='invoice') then raise exception 'Certified vendor invoice document required before review' using errcode='23505';end if;
  if exists(select 1 from public.vendor_invoice_evidence where invoice_id=old.id and state='reserved' and expires_at>statement_timestamp()) then raise exception 'Finish or withdraw pending invoice uploads before review' using errcode='23505';end if;
  insert into public.vendor_invoice_review_evidence(invoice_id,evidence_id,organization_id,reviewed_version,kind,file_name,mime_type,sha256,actual_size)
   select old.id,e.id,old.organization_id,new.version,e.kind,e.file_name,e.mime_type,e.sha256,e.actual_size from public.vendor_invoice_evidence e where e.invoice_id=old.id and e.organization_id=old.organization_id and e.user_id=old.submitted_by and e.state='uploaded';
 end if;
 if new.state='approved' and old.state is distinct from new.state and not exists(select 1 from public.vendor_invoice_review_evidence where invoice_id=old.id and organization_id=old.organization_id and kind='invoice' and reviewed_version=old.version) then raise exception 'Reviewed invoice evidence snapshot required before approval' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.freeze_invoice_review_evidence() from public,anon,authenticated,service_role;
create trigger freeze_invoice_review_evidence before update of state on public.reviewed_vendor_invoices for each row execute function private.freeze_invoice_review_evidence();

create function private.guard_invoice_evidence_review_stage() returns trigger
language plpgsql security definer set search_path='' as $$
declare stage text;
begin
 if (old.state='reserved' and new.state='uploaded') or (old.state='uploaded' and new.state is distinct from old.state) then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(old.organization_id::text,119));
  select state into stage from public.reviewed_vendor_invoices where id=old.invoice_id for share;
  if stage is distinct from 'submitted' then raise exception 'Invoice evidence is frozen after review starts' using errcode='23505';end if;
 end if;
 if new.purged_at is distinct from old.purged_at and new.state not in('withdrawn','expired') then raise exception 'Current invoice evidence cannot be purged' using errcode='23505';end if;
 return new;
end $$;
revoke all on function private.guard_invoice_evidence_review_stage() from public,anon,authenticated,service_role;
create trigger guard_invoice_evidence_review_stage before update on public.vendor_invoice_evidence for each row execute function private.guard_invoice_evidence_review_stage();
