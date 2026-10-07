-- Private legal PDFs. Upload authority is added through scoped RPCs in a subsequent migration.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('lease-template-documents','lease-template-documents',false,8388608,array['application/pdf']) on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=excluded.allowed_mime_types;
create table public.lease_template_documents(
 id uuid primary key default gen_random_uuid(),template_id uuid not null references public.approved_lease_templates(id),organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),request_id uuid not null,
 file_name text not null check(length(trim(file_name)) between 1 and 160 and file_name !~ E'[\\x00-\\x1f\\x7f/\\\\]'),mime_type text not null default 'application/pdf' check(mime_type='application/pdf'),declared_size bigint not null check(declared_size between 1 and 8388608),object_path text not null unique,
 expected_sha256 text not null check(expected_sha256 ~ '^[a-f0-9]{64}$'),state text not null default 'reserved' check(state in('reserved','certified','withdrawn','expired')),
 sha256 text,actual_size bigint,expires_at timestamptz not null default statement_timestamp()+interval '30 minutes',certified_at timestamptz,withdrawn_at timestamptz,purged_at timestamptz,created_at timestamptz not null default statement_timestamp(),unique(user_id,request_id),
 check(sha256 is null or sha256=expected_sha256),check(actual_size is null or actual_size=declared_size),check(state<>'certified' or (sha256=expected_sha256 and sha256 is not null and actual_size is not null and certified_at is not null and purged_at is null))
);
create unique index lease_template_certified_document_idx on public.lease_template_documents(template_id) where state='certified';
create index lease_template_document_scope_idx on public.lease_template_documents(organization_id,template_id,state,created_at desc,id);
alter table public.lease_template_documents enable row level security;
revoke all on public.lease_template_documents from public,anon,authenticated,service_role;
grant select on public.lease_template_documents to authenticated,service_role;
create policy "verified staff read certified legal documents or own reservations" on public.lease_template_documents for select to authenticated using(organization_id=(select private.verified_enquiry_staff_organization()) and (state='certified' or user_id=(select auth.uid())));
create table public.lease_template_document_events(
 id uuid primary key default gen_random_uuid(),document_id uuid not null references public.lease_template_documents(id),actor_user_id uuid references auth.users(id),event_name text not null check(event_name in('reserved','certified','withdrawn','expired')),created_at timestamptz not null default statement_timestamp()
);
alter table public.lease_template_document_events enable row level security;
revoke all on public.lease_template_document_events from public,anon,authenticated,service_role;
grant select on public.lease_template_document_events to authenticated,service_role;
create policy "read accessible legal document events" on public.lease_template_document_events for select to authenticated using(exists(select 1 from public.lease_template_documents d where d.id=document_id));
create trigger immutable_lease_template_document_events before update or delete on public.lease_template_document_events for each row execute function private.guard_finance_immutable();
create function private.guard_lease_template_document() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Legal document history is retained' using errcode='23505';end if;
 if tg_op='INSERT' then
  if new.state<>'reserved' or new.sha256 is not null or new.actual_size is not null or new.certified_at is not null or new.withdrawn_at is not null or new.purged_at is not null then raise exception 'Start with an uncertified reservation' using errcode='23505';end if;
  if not exists(select 1 from public.approved_lease_templates t join public.staff_accounts s on s.organization_id=t.organization_id and s.user_id=new.user_id join auth.users u on u.id=s.user_id where t.id=new.template_id and t.organization_id=new.organization_id and t.content_sha256=new.expected_sha256 and s.role='admin' and u.email_confirmed_at is not null) then raise exception 'Verified administrator and approved fingerprint binding required' using errcode='42501';end if;
 else
  if row(new.id,new.template_id,new.organization_id,new.user_id,new.request_id,new.file_name,new.mime_type,new.declared_size,new.object_path,new.expected_sha256,new.expires_at,new.created_at) is distinct from row(old.id,old.template_id,old.organization_id,old.user_id,old.request_id,old.file_name,old.mime_type,old.declared_size,old.object_path,old.expected_sha256,old.expires_at,old.created_at) then raise exception 'Legal document identity is immutable' using errcode='23505';end if;
  if old.state='certified' then raise exception 'Certified legal document is immutable' using errcode='23505';end if;
  if new.state is distinct from old.state and not(old.state='reserved' and new.state in('certified','withdrawn','expired')) then raise exception 'Legal document transition unavailable' using errcode='23505';end if;
  if old.state in('expired','withdrawn') and row(new.sha256,new.actual_size,new.certified_at,new.withdrawn_at) is distinct from row(old.sha256,old.actual_size,old.certified_at,old.withdrawn_at) then raise exception 'Terminal certification metadata is immutable' using errcode='23505';end if;
  if old.state='reserved' and new.state<>'certified' and row(new.sha256,new.actual_size,new.certified_at) is distinct from row(old.sha256,old.actual_size,old.certified_at) then raise exception 'Certification requires certified state' using errcode='23505';end if;
  if new.purged_at is distinct from old.purged_at and new.state not in('withdrawn','expired') then raise exception 'Current legal documents cannot be purged' using errcode='23505';end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_lease_template_document() from public,anon,authenticated,service_role;
create trigger guard_lease_template_document before insert or update or delete on public.lease_template_documents for each row execute function private.guard_lease_template_document();
-- Deliberately no client Storage insert, overwrite or deletion policies yet.
