insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('contractor-evidence','contractor-evidence',false,8388608,array['application/pdf','image/jpeg','image/png']) on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=excluded.allowed_mime_types;
create table public.contractor_evidence(
 id uuid primary key default gen_random_uuid(),offer_id uuid not null references public.contractor_work_offers(id),organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),request_id uuid not null,
 file_name text not null,mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),declared_size bigint not null check(declared_size between 1 and 8388608),object_path text not null unique,
 state text not null default 'reserved' check(state in('reserved','uploaded','withdrawn','expired')),sha256 text check(sha256 is null or sha256 ~ '^[a-f0-9]{64}$'),actual_size bigint,expires_at timestamptz not null default now()+interval '30 minutes',uploaded_at timestamptz,withdrawn_at timestamptz,purged_at timestamptz,created_at timestamptz not null default now(),unique(user_id,request_id)
);
create index contractor_evidence_offer_idx on public.contractor_evidence(offer_id,created_at desc,id);
create index contractor_evidence_org_idx on public.contractor_evidence(organization_id,state,created_at desc,id);
create index contractor_evidence_user_idx on public.contractor_evidence(user_id,created_at desc,id);
alter table public.contractor_evidence enable row level security;
revoke all on public.contractor_evidence from public,anon,authenticated;
grant select on public.contractor_evidence to authenticated;
grant select,insert,update on public.contractor_evidence to service_role;
create policy "contractors read own evidence" on public.contractor_evidence for select to authenticated using(user_id=(select private.verified_contractor_user()));
create policy "managers read uploaded evidence" on public.contractor_evidence for select to authenticated using(state='uploaded' and organization_id=(select private.verified_work_order_organization()));
create table public.contractor_report_evidence(
 report_id uuid not null references public.contractor_completion_reports(id),evidence_id uuid not null references public.contractor_evidence(id),primary key(report_id,evidence_id)
);
create index contractor_report_evidence_document_idx on public.contractor_report_evidence(evidence_id,report_id);
alter table public.contractor_report_evidence enable row level security;
revoke all on public.contractor_report_evidence from public,anon,authenticated;
grant select on public.contractor_report_evidence to authenticated;
grant select,insert on public.contractor_report_evidence to service_role;
create policy "read own accessible report evidence" on public.contractor_report_evidence for select to authenticated using(exists(select 1 from public.contractor_completion_reports r where r.id=report_id));
create table public.contractor_evidence_events(
 id uuid primary key default gen_random_uuid(),evidence_id uuid not null references public.contractor_evidence(id),actor_user_id uuid not null references auth.users(id),event_name text not null,created_at timestamptz not null default now()
);
create index contractor_evidence_events_idx on public.contractor_evidence_events(evidence_id,created_at desc,id);
alter table public.contractor_evidence_events enable row level security;
revoke all on public.contractor_evidence_events from public,anon,authenticated;
grant select on public.contractor_evidence_events to authenticated;
grant select,insert on public.contractor_evidence_events to service_role;
create policy "read accessible evidence events" on public.contractor_evidence_events for select to authenticated using(exists(select 1 from public.contractor_evidence e where e.id=evidence_id));
create function private.contractor_evidence_mutable(p_offer_id uuid,p_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.contractor_work_offers o join public.contractor_accounts c on c.id=o.contractor_id join public.work_orders w on w.id=o.work_order_id join auth.users u on u.id=c.user_id where o.id=p_offer_id and o.state='accepted' and o.work_version=w.revision and w.status in('on_site','in_progress') and c.user_id=p_user_id and c.is_active and u.email_confirmed_at is not null)
 and not exists(select 1 from public.contractor_completion_reports r where r.offer_id=p_offer_id and r.state='submitted');
$$;
revoke all on function private.contractor_evidence_mutable(uuid,uuid) from public,anon,authenticated;
create function private.contractor_evidence_storage_access(p_path text,p_operation text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=auth.uid();doc public.contractor_evidence;
begin
 if caller is null or private.verified_contractor_user() is null then return false;end if;
 select * into doc from public.contractor_evidence where object_path=p_path;if doc.id is null then return false;end if;
 if p_operation='insert' then return doc.user_id=caller and doc.state='reserved' and doc.expires_at>now() and private.contractor_evidence_mutable(doc.offer_id,caller);end if;
 if p_operation='read' then return (doc.state='uploaded' and (doc.user_id=caller or doc.organization_id=private.verified_work_order_organization())) or (doc.user_id=caller and doc.state='reserved' and doc.expires_at>now() and private.contractor_evidence_mutable(doc.offer_id,caller));end if;
 return false;
end $$;
revoke all on function private.contractor_evidence_storage_access(text,text) from public,anon,authenticated;
grant execute on function private.contractor_evidence_storage_access(text,text) to authenticated;
create policy "private contractor file insert" on storage.objects for insert to authenticated with check(bucket_id='contractor-evidence' and private.contractor_evidence_storage_access(name,'insert'));
create policy "private contractor file read" on storage.objects for select to authenticated using(bucket_id='contractor-evidence' and private.contractor_evidence_storage_access(name,'read'));
-- No client overwrite or removal policy.
create function private.guard_contractor_evidence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.offer_id,new.organization_id,new.user_id,new.request_id,new.file_name,new.mime_type,new.declared_size,new.object_path,new.expires_at,new.created_at) is distinct from row(old.offer_id,old.organization_id,old.user_id,old.request_id,old.file_name,old.mime_type,old.declared_size,old.object_path,old.expires_at,old.created_at) then raise exception 'Evidence identity immutable' using errcode='23505';end if;
 if tg_op='UPDATE' and old.state='uploaded' and row(new.sha256,new.actual_size,new.uploaded_at) is distinct from row(old.sha256,old.actual_size,old.uploaded_at) then raise exception 'Verified evidence bytes immutable' using errcode='23505';end if;
 if tg_op='UPDATE' and new.state is distinct from old.state and exists(select 1 from public.contractor_report_evidence where evidence_id=old.id) then raise exception 'Submitted report evidence is frozen' using errcode='23505';end if;
 if not exists(select 1 from public.contractor_work_offers o join public.contractor_accounts c on c.id=o.contractor_id where o.id=new.offer_id and o.organization_id=new.organization_id and c.user_id=new.user_id) then raise exception 'Evidence assignment binding required' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_contractor_evidence() from public,anon,authenticated;
create trigger guard_contractor_evidence before insert or update on public.contractor_evidence for each row execute function private.guard_contractor_evidence();
create function private.reserve_contractor_evidence(p_offer_id uuid,p_request_id uuid,p_file_name text,p_mime_type text,p_size bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();offer public.contractor_work_offers;doc public.contractor_evidence;created uuid:=gen_random_uuid();path text;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified contractor required' using errcode='42501';end if;
 select * into offer from public.contractor_work_offers where id=p_offer_id;
 if offer.id is null or not exists(select 1 from public.contractor_accounts c where c.id=offer.contractor_id and c.user_id=caller and c.is_active) then raise exception 'Assigned contractor required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(offer.organization_id::text,119));
 if not private.contractor_evidence_mutable(offer.id,caller) then raise exception 'Evidence editing unavailable' using errcode='23505';end if;
 if p_request_id is null or p_file_name is null or length(trim(p_file_name)) not between 1 and 160 or p_file_name<>regexp_replace(p_file_name,'[[:cntrl:]]','','g') or position('/' in p_file_name)>0 or position(chr(92) in p_file_name)>0 or p_mime_type is null or p_mime_type not in('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 8388608 then raise exception 'Valid file reservation required' using errcode='22023';end if;
 select * into doc from public.contractor_evidence where user_id=caller and request_id=p_request_id;
 if doc.id is not null then
 if doc.offer_id<>offer.id or doc.file_name<>trim(p_file_name) or doc.mime_type<>p_mime_type or doc.declared_size<>p_size then raise exception 'Request ID already used' using errcode='22023';end if;
 if doc.state not in('reserved','uploaded') or (doc.state='reserved' and doc.expires_at<=now()) then raise exception 'Start a new reservation' using errcode='23505';end if;
 return jsonb_build_object('id',doc.id,'path',doc.object_path,'state',doc.state);end if;
 if(select count(*) from public.contractor_evidence where offer_id=offer.id and (state='uploaded' or state='reserved' and expires_at>now()))>=10 or(select count(*) from public.contractor_evidence where user_id=caller and created_at>now()-interval '1 day')>=50 then raise exception 'Evidence upload limit reached' using errcode='23505';end if;
 path:=offer.id::text||'/'||created::text||case p_mime_type when 'application/pdf' then '.pdf' when 'image/jpeg' then '.jpg' else '.png' end;
 insert into public.contractor_evidence(id,offer_id,organization_id,user_id,request_id,file_name,mime_type,declared_size,object_path) values(created,offer.id,offer.organization_id,caller,p_request_id,trim(p_file_name),p_mime_type,p_size,path);
 insert into public.contractor_evidence_events(evidence_id,actor_user_id,event_name) values(created,caller,'reserved');
 return jsonb_build_object('id',created,'path',path,'state','reserved');
end $$;
revoke all on function private.reserve_contractor_evidence(uuid,uuid,text,text,bigint) from public,anon,authenticated;
grant execute on function private.reserve_contractor_evidence(uuid,uuid,text,text,bigint) to authenticated;
create function public.reserve_contractor_evidence(p_offer_id uuid,p_request_id uuid,p_file_name text,p_mime_type text,p_size bigint) returns jsonb language sql security invoker set search_path='' as $$select private.reserve_contractor_evidence(p_offer_id,p_request_id,p_file_name,p_mime_type,p_size);$$;
revoke all on function public.reserve_contractor_evidence(uuid,uuid,text,text,bigint) from public,anon,authenticated;
grant execute on function public.reserve_contractor_evidence(uuid,uuid,text,text,bigint) to authenticated;
create function public.finish_contractor_evidence(p_actor uuid,p_evidence_id uuid,p_size bigint,p_mime_type text,p_sha256 text) returns boolean language plpgsql security invoker set search_path='' as $$
declare doc public.contractor_evidence;
begin
 select * into doc from public.contractor_evidence where id=p_evidence_id;
 if doc.id is null or doc.user_id is distinct from p_actor then raise exception 'Evidence unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into doc from public.contractor_evidence where id=p_evidence_id for update;
 if p_size is distinct from doc.declared_size or p_mime_type is distinct from doc.mime_type or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Verified bytes must match reservation' using errcode='22023';end if;
 if doc.state='uploaded' then if doc.sha256<>p_sha256 or doc.actual_size<>p_size then raise exception 'Evidence is immutable' using errcode='23505';end if;return true;end if;
 if doc.state<>'reserved' or doc.expires_at<=now() or not private.contractor_evidence_mutable(doc.offer_id,p_actor) then raise exception 'Reservation unavailable' using errcode='23505';end if;
 update public.contractor_evidence set state='uploaded',sha256=p_sha256,actual_size=p_size,uploaded_at=now() where id=doc.id;
 insert into public.contractor_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,p_actor,'uploaded_format_checked');return true;
end $$;
revoke all on function public.finish_contractor_evidence(uuid,uuid,bigint,text,text) from public,anon,authenticated;
grant execute on function public.finish_contractor_evidence(uuid,uuid,bigint,text,text) to service_role;
create function private.withdraw_contractor_evidence(p_evidence_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();doc public.contractor_evidence;
begin
 if caller is null or private.verified_contractor_user() is null then raise exception 'Verified contractor required' using errcode='42501';end if;
 select * into doc from public.contractor_evidence where id=p_evidence_id;
 if doc.id is null or doc.user_id<>caller then raise exception 'Own evidence required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into doc from public.contractor_evidence where id=p_evidence_id for update;
 if not private.contractor_evidence_mutable(doc.offer_id,caller) or exists(select 1 from public.contractor_report_evidence where evidence_id=doc.id) then raise exception 'Submitted evidence cannot be withdrawn' using errcode='23505';end if;
 if doc.state='withdrawn' then return true;end if;
 update public.contractor_evidence set state='withdrawn',withdrawn_at=now() where id=doc.id;
 insert into public.contractor_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,caller,'withdrawn');return true;
end $$;
revoke all on function private.withdraw_contractor_evidence(uuid) from public,anon,authenticated;
grant execute on function private.withdraw_contractor_evidence(uuid) to authenticated;
create function public.withdraw_contractor_evidence(p_evidence_id uuid) returns boolean language sql security invoker set search_path='' as $$select private.withdraw_contractor_evidence(p_evidence_id);$$;
revoke all on function public.withdraw_contractor_evidence(uuid) from public,anon,authenticated;
grant execute on function public.withdraw_contractor_evidence(uuid) to authenticated;
-- Freeze every verified uploaded file for the assignment at report submission.
create function private.freeze_completion_evidence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.organization_id::text,119));
 insert into public.contractor_report_evidence(report_id,evidence_id) select new.id,e.id from public.contractor_evidence e where e.offer_id=new.offer_id and e.user_id=new.contractor_user_id and e.state='uploaded';
 return new;
end $$;
revoke all on function private.freeze_completion_evidence() from public,anon,authenticated;
create trigger freeze_completion_evidence after insert on public.contractor_completion_reports for each row execute function private.freeze_completion_evidence();
