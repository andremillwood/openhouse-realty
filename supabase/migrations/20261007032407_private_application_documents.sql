insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('application-documents','application-documents',false,8388608,array['application/pdf','image/jpeg','image/png']) on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=excluded.allowed_mime_types;
create table public.application_documents (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.rental_applications(id),
 organization_id uuid not null references public.organizations(id),
 user_id uuid not null references auth.users(id),
 request_id uuid not null,
 kind text not null check(kind in('identity','income','reference','other')),
 file_name text not null check(length(file_name) between 1 and 160),
 mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),
 declared_size bigint not null check(declared_size between 1 and 8388608),
 object_path text not null unique,
 state text not null default 'reserved' check(state in('reserved','uploaded','withdrawn','expired')),
 sha256 text check(sha256 is null or sha256 ~ '^[a-f0-9]{64}$'),
 actual_size bigint,
 expires_at timestamptz not null default now()+interval '30 minutes',
 uploaded_at timestamptz,
 withdrawn_at timestamptz,
 purged_at timestamptz,
 created_at timestamptz not null default now(),
 unique(user_id,request_id)
);
create index application_documents_app_idx on public.application_documents(application_id,created_at desc);
create index application_documents_org_idx on public.application_documents(organization_id);
create index application_documents_user_idx on public.application_documents(user_id,created_at desc);
alter table public.application_documents enable row level security;
revoke all on public.application_documents from public,anon,authenticated;
grant select on public.application_documents to authenticated;
grant select,insert,update on public.application_documents to service_role;
create policy "applicants read own document records" on public.application_documents for select to authenticated using(user_id=(select auth.uid()));
create policy "verified staff read uploaded organization documents" on public.application_documents for select to authenticated using(state='uploaded' and organization_id=(select private.verified_enquiry_staff_organization()));
create table public.application_document_events (
 id uuid primary key default gen_random_uuid(),
 document_id uuid not null references public.application_documents(id),
 actor_user_id uuid not null references auth.users(id),
 event_name text not null,
 created_at timestamptz not null default now()
);
create index application_document_events_doc_idx on public.application_document_events(document_id,created_at desc);
alter table public.application_document_events enable row level security;
revoke all on public.application_document_events from public,anon,authenticated;
grant select on public.application_document_events to authenticated;
grant select,insert on public.application_document_events to service_role;
create policy "read accessible document event history" on public.application_document_events for select to authenticated using(exists(select 1 from public.application_documents where id=document_id));

create function private.application_document_storage_access(p_path text,p_operation text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=auth.uid(); doc public.application_documents; application public.rental_applications;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then return false;end if;
 select * into doc from public.application_documents where object_path=p_path;
 if doc.id is null then return false;end if;
 select * into application from public.rental_applications where id=doc.application_id;
 if p_operation='insert' then return doc.user_id=caller and application.user_id=caller and doc.state='reserved' and doc.expires_at>now() and application.status in('submitted','under_review','needs_info');end if;
 if p_operation='read' then return (doc.state='uploaded' and (doc.user_id=caller or doc.organization_id=private.verified_enquiry_staff_organization())) or (doc.user_id=caller and doc.state='reserved' and doc.expires_at>now());end if;
 return false;
end $$;
revoke all on function private.application_document_storage_access(text,text) from public,anon;
grant execute on function private.application_document_storage_access(text,text) to authenticated;
create policy "application private file uploads" on storage.objects for insert to authenticated with check(bucket_id='application-documents' and private.application_document_storage_access(name,'insert'));
create policy "application private file reads" on storage.objects for select to authenticated using(bucket_id='application-documents' and private.application_document_storage_access(name,'read'));
-- No client UPDATE/DELETE policies: upserts and direct removal are denied.

create function private.reserve_application_document(p_application_id uuid,p_request_id uuid,p_kind text,p_file_name text,p_mime_type text,p_size bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); application public.rental_applications; existing public.application_documents; created uuid:=gen_random_uuid(); path text; extension text;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified applicant required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,112));
 select * into application from public.rental_applications where id=p_application_id for update;
 if application.id is null or application.user_id<>caller then raise exception 'Applicant document access required' using errcode='42501';end if;
 if p_request_id is null or p_kind is null or p_kind not in('identity','income','reference','other') or p_file_name is null or length(p_file_name) not between 1 and 160 or p_file_name<>regexp_replace(p_file_name,'[[:cntrl:]]','','g') or position('/' in p_file_name)>0 or position(chr(92) in p_file_name)>0 or p_mime_type is null or p_mime_type not in('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 8388608 then raise exception 'Invalid private document' using errcode='22023';end if;
 select * into existing from public.application_documents where user_id=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.application_id<>application.id or existing.kind<>p_kind or existing.file_name<>p_file_name or existing.mime_type<>p_mime_type or existing.declared_size<>p_size then raise exception 'Request ID already used' using errcode='22023';end if;
  if existing.state='uploaded' then return jsonb_build_object('id',existing.id,'path',existing.object_path,'state',existing.state);end if;
  if existing.state<>'reserved' or existing.expires_at<=now() then raise exception 'Upload reservation expired or withdrawn; start a new request' using errcode='P0001';end if;
  return jsonb_build_object('id',existing.id,'path',existing.object_path,'state',existing.state);
 end if;
 if application.status not in('submitted','under_review','needs_info') then raise exception 'Application does not allow new documents' using errcode='22023';end if;
 if (select count(*) from public.application_documents where application_id=application.id and (state='uploaded' or (state='reserved' and expires_at>now())))>=10 or (select count(*) from public.application_documents where user_id=caller and created_at>now()-interval '1 day')>=50 then raise exception 'Document limit reached' using errcode='P0001';end if;
 extension:=case p_mime_type when 'application/pdf' then 'pdf' when 'image/jpeg' then 'jpg' else 'png' end;
 path:=application.id::text||'/'||created::text||'.'||extension;
 insert into public.application_documents(id,application_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path) values(created,application.id,application.organization_id,caller,p_request_id,p_kind,p_file_name,p_mime_type,p_size,path);
 insert into public.application_document_events(document_id,actor_user_id,event_name) values(created,caller,'reserved');
 return jsonb_build_object('id',created,'path',path,'state','reserved');
end $$;
revoke all on function private.reserve_application_document(uuid,uuid,text,text,text,bigint) from public,anon;
grant execute on function private.reserve_application_document(uuid,uuid,text,text,text,bigint) to authenticated;
create function public.reserve_application_document(p_application_id uuid,p_request_id uuid,p_kind text,p_file_name text,p_mime_type text,p_size bigint) returns jsonb language sql security invoker set search_path='' as $$select private.reserve_application_document(p_application_id,p_request_id,p_kind,p_file_name,p_mime_type,p_size);$$;
revoke all on function public.reserve_application_document(uuid,uuid,text,text,text,bigint) from public,anon;
grant execute on function public.reserve_application_document(uuid,uuid,text,text,text,bigint) to authenticated;

-- Only the trusted server can certify bytes actually retrieved from Storage.
create function public.finish_application_document(p_actor uuid,p_document_id uuid,p_size bigint,p_mime_type text,p_sha256 text) returns boolean language plpgsql security invoker set search_path='' as $$
declare doc public.application_documents; application public.rental_applications;
begin
 select * into doc from public.application_documents where id=p_document_id;
 if doc.id is null or doc.user_id is distinct from p_actor then raise exception 'Document access unavailable' using errcode='42501';end if;
 select * into application from public.rental_applications where id=doc.application_id for update;
 select * into doc from public.application_documents where id=p_document_id for update;
 if p_size is distinct from doc.declared_size or p_mime_type is distinct from doc.mime_type or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Uploaded file does not match reservation' using errcode='22023';end if;
 if doc.state='uploaded' then
  if doc.sha256<>p_sha256 or doc.actual_size<>p_size then raise exception 'Uploaded document is immutable' using errcode='22023';end if;
  return true;
 end if;
 if doc.state<>'reserved' or doc.expires_at<=now() or application.status not in('submitted','under_review','needs_info') then raise exception 'Upload reservation no longer active' using errcode='P0001';end if;
 update public.application_documents set state='uploaded',actual_size=p_size,sha256=p_sha256,uploaded_at=now() where id=doc.id;
 insert into public.application_document_events(document_id,actor_user_id,event_name) values(doc.id,p_actor,'uploaded_format_checked');
 return true;
end $$;
revoke all on function public.finish_application_document(uuid,uuid,bigint,text,text) from public,anon,authenticated;
grant execute on function public.finish_application_document(uuid,uuid,bigint,text,text) to service_role;

create function private.withdraw_application_document(p_document_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); doc public.application_documents; application public.rental_applications;
begin
 if caller is null or not exists(select 1 from auth.users where id=caller and email_confirmed_at is not null) then raise exception 'Verified applicant required' using errcode='42501';end if;
 select * into doc from public.application_documents where id=p_document_id;
 if doc.id is null or doc.user_id<>caller then raise exception 'Applicant document access required' using errcode='42501';end if;
 select * into application from public.rental_applications where id=doc.application_id for update;
 select * into doc from public.application_documents where id=p_document_id for update;
 if doc.state='withdrawn' then return true;end if;
 if application.status not in('submitted','under_review','needs_info') then raise exception 'Document changes are closed at this application stage' using errcode='22023';end if;
 update public.application_documents set state='withdrawn',withdrawn_at=now() where id=doc.id;
 insert into public.application_document_events(document_id,actor_user_id,event_name) values(doc.id,caller,'withdrawn');
 return true;
end $$;
revoke all on function private.withdraw_application_document(uuid) from public,anon;
grant execute on function private.withdraw_application_document(uuid) to authenticated;
create function public.withdraw_application_document(p_document_id uuid) returns boolean language sql security invoker set search_path='' as $$select private.withdraw_application_document(p_document_id);$$;
revoke all on function public.withdraw_application_document(uuid) from public,anon;
grant execute on function public.withdraw_application_document(uuid) to authenticated;

-- Signed upload tokens last two hours. Wait beyond the latest possible token expiry
-- before deletion, so an old token cannot recreate an object after cleanup.
create function public.claim_expired_application_documents() returns table(id uuid,object_path text) language plpgsql security invoker set search_path='' as $$
begin
 return query with candidates as (
 select d.id from public.application_documents d
 where d.purged_at is null and d.expires_at+interval '2 hours 5 minutes'<now()
 and d.state in('reserved','expired','withdrawn')
 order by d.created_at limit 20 for update skip locked
 ), expired as (
 update public.application_documents d set state=case when d.state='reserved' then 'expired' else d.state end
 from candidates c where d.id=c.id returning d.id,d.object_path
 ) select e.id,e.object_path from expired e;
end $$;
revoke all on function public.claim_expired_application_documents() from public,anon,authenticated;
grant execute on function public.claim_expired_application_documents() to service_role;
