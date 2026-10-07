-- Organization lock 119 also serializes cheque decisions and membership changes.
create function private.cheque_evidence_mutable(p_cheque_id uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.audited_cheque_receipts i
 join public.staff_accounts s on s.user_id=p_actor and s.organization_id=i.organization_id
 join auth.users u on u.id=s.user_id
 where i.id=p_cheque_id and i.state='received'
 and s.role in('admin','finance') and u.email_confirmed_at is not null);
$$;
revoke all on function private.cheque_evidence_mutable(uuid,uuid) from public,anon,authenticated,service_role;

create function private.reserve_cheque_evidence(p_cheque_id uuid,p_request_id uuid,p_kind text,p_file_name text,p_mime_type text,p_size bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();inv public.audited_cheque_receipts;doc public.cheque_bank_evidence;created uuid:=gen_random_uuid();path text;
begin
 if caller is null or org is null then raise exception 'Verified finance staff required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into inv from public.audited_cheque_receipts where id=p_cheque_id and organization_id=org for update;
 if inv.id is null then raise exception 'Own organization cheque required' using errcode='42501';end if;
 if not private.cheque_evidence_mutable(inv.id,caller) then raise exception 'Cheque evidence editing unavailable' using errcode='23505';end if;
 if p_request_id is null or p_kind is null or p_kind not in('deposit','clearance','return') or p_file_name is null or length(trim(p_file_name)) not between 1 and 160 or p_file_name<>regexp_replace(p_file_name,'[[:cntrl:]]','','g') or position('/' in p_file_name)>0 or position(chr(92) in p_file_name)>0 or p_mime_type is null or p_mime_type not in('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 8388608 then raise exception 'Valid cheque file metadata required' using errcode='22023';end if;
 select * into doc from public.cheque_bank_evidence where user_id=caller and request_id=p_request_id;
 if doc.id is not null then
  if doc.cheque_id<>inv.id or doc.organization_id<>org or doc.kind<>p_kind or doc.file_name<>trim(p_file_name) or doc.mime_type<>p_mime_type or doc.declared_size<>p_size then raise exception 'Request ID already used' using errcode='22023';end if;
  if doc.state not in('reserved','uploaded') or (doc.state='reserved' and doc.expires_at<=statement_timestamp()) then raise exception 'Start a new reservation' using errcode='23505';end if;
  return jsonb_build_object('id',doc.id,'path',doc.object_path,'state',doc.state);
 end if;
 if (select count(*) from public.cheque_bank_evidence where cheque_id=inv.id and (state='uploaded' or state='reserved' and expires_at>statement_timestamp()))>=10 or (select count(*) from public.cheque_bank_evidence where user_id=caller and created_at>statement_timestamp()-interval '1 day')>=50 then raise exception 'Cheque evidence upload limit reached' using errcode='23505';end if;
 path:=inv.id::text||'/'||created::text||case p_mime_type when 'application/pdf' then '.pdf' when 'image/jpeg' then '.jpg' else '.png' end;
 insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path) values(created,inv.id,org,caller,p_request_id,p_kind,trim(p_file_name),p_mime_type,p_size,path);
 insert into public.cheque_bank_evidence_events(evidence_id,actor_user_id,event_name) values(created,caller,'reserved');
 return jsonb_build_object('id',created,'path',path,'state','reserved');
end $$;
revoke all on function private.reserve_cheque_evidence(uuid,uuid,text,text,text,bigint) from public,anon,authenticated,service_role;
grant execute on function private.reserve_cheque_evidence(uuid,uuid,text,text,text,bigint) to authenticated;
create function public.reserve_cheque_evidence(p_cheque_id uuid,p_request_id uuid,p_kind text,p_file_name text,p_mime_type text,p_size bigint) returns jsonb
language sql security invoker set search_path='' as $$select private.reserve_cheque_evidence(p_cheque_id,p_request_id,p_kind,p_file_name,p_mime_type,p_size);$$;
revoke all on function public.reserve_cheque_evidence(uuid,uuid,text,text,text,bigint) from public,anon,authenticated,service_role;
grant execute on function public.reserve_cheque_evidence(uuid,uuid,text,text,text,bigint) to authenticated;

create function private.cheque_evidence_storage_access(p_path text,p_operation text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();doc public.cheque_bank_evidence;
begin
 if caller is null or org is null then return false;end if;
 select * into doc from public.cheque_bank_evidence where object_path=p_path and organization_id=org;
 if doc.id is null then return false;end if;
 if p_operation='read' and doc.state='uploaded' then return true;end if;
 if p_operation in('read','insert') then return doc.user_id=caller and doc.state='reserved' and doc.expires_at>statement_timestamp() and private.cheque_evidence_mutable(doc.cheque_id,caller);end if;
 return false;
end $$;
revoke all on function private.cheque_evidence_storage_access(text,text) from public,anon,authenticated,service_role;
grant execute on function private.cheque_evidence_storage_access(text,text) to authenticated;
create policy "private cheque file insert" on storage.objects for insert to authenticated with check(bucket_id='cheque-bank-evidence' and private.cheque_evidence_storage_access(name,'insert'));
create policy "private cheque file read" on storage.objects for select to authenticated using(bucket_id='cheque-bank-evidence' and private.cheque_evidence_storage_access(name,'read'));
-- Deliberately no client overwrite or removal policy.

create function private.finish_cheque_evidence(p_actor uuid,p_evidence_id uuid,p_size bigint,p_mime_type text,p_sha256 text) returns boolean
language plpgsql security definer set search_path='' as $$
declare doc public.cheque_bank_evidence;inv public.audited_cheque_receipts;
begin
 select * into doc from public.cheque_bank_evidence where id=p_evidence_id;
 if doc.id is null or doc.user_id is distinct from p_actor then raise exception 'Own cheque evidence required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into inv from public.audited_cheque_receipts where id=doc.cheque_id for update;
 select * into doc from public.cheque_bank_evidence where id=p_evidence_id for update;
 if not private.cheque_evidence_mutable(inv.id,p_actor) then raise exception 'Cheque evidence editing unavailable' using errcode='23505';end if;
 if p_size is distinct from doc.declared_size or p_mime_type is distinct from doc.mime_type or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Certified bytes must match reservation' using errcode='22023';end if;
 if doc.state='uploaded' then
  if doc.sha256<>p_sha256 or doc.actual_size<>p_size then raise exception 'Certified evidence is immutable' using errcode='23505';end if;return true;
 end if;
 if doc.state<>'reserved' or doc.expires_at<=statement_timestamp() then raise exception 'Reservation unavailable' using errcode='23505';end if;
 if not exists(select 1 from storage.objects where bucket_id='cheque-bank-evidence' and name=doc.object_path) then raise exception 'Uploaded object required' using errcode='23505';end if;
 update public.cheque_bank_evidence set state='uploaded',actual_size=p_size,sha256=p_sha256,uploaded_at=statement_timestamp() where id=doc.id;
 insert into public.cheque_bank_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,p_actor,'uploaded');
 return true;
end $$;
revoke all on function private.finish_cheque_evidence(uuid,uuid,bigint,text,text) from public,anon,authenticated,service_role;
grant execute on function private.finish_cheque_evidence(uuid,uuid,bigint,text,text) to service_role;
create function public.finish_cheque_evidence(p_actor uuid,p_evidence_id uuid,p_size bigint,p_mime_type text,p_sha256 text) returns boolean
language sql security invoker set search_path='' as $$select private.finish_cheque_evidence(p_actor,p_evidence_id,p_size,p_mime_type,p_sha256);$$;
revoke all on function public.finish_cheque_evidence(uuid,uuid,bigint,text,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_cheque_evidence(uuid,uuid,bigint,text,text) to service_role;

create function private.withdraw_cheque_evidence(p_evidence_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_finance_organization();doc public.cheque_bank_evidence;
begin
 if caller is null or org is null then raise exception 'Verified finance staff required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_finance_organization() is distinct from org then raise exception 'Finance authority changed' using errcode='42501';end if;
 select * into doc from public.cheque_bank_evidence where id=p_evidence_id and organization_id=org and user_id=caller;
 if doc.id is null then raise exception 'Own cheque evidence required' using errcode='42501';end if;
 perform 1 from public.audited_cheque_receipts where id=doc.cheque_id for update;
 select * into doc from public.cheque_bank_evidence where id=p_evidence_id for update;
 if not private.cheque_evidence_mutable(doc.cheque_id,caller) then raise exception 'Cheque evidence editing unavailable' using errcode='23505';end if;
 if doc.state='withdrawn' then return true;end if;
 if doc.state not in('reserved','uploaded') then raise exception 'Evidence withdrawal unavailable' using errcode='23505';end if;
 update public.cheque_bank_evidence set state='withdrawn',withdrawn_at=statement_timestamp() where id=doc.id;
 insert into public.cheque_bank_evidence_events(evidence_id,actor_user_id,event_name) values(doc.id,caller,'withdrawn');return true;
end $$;
revoke all on function private.withdraw_cheque_evidence(uuid) from public,anon,authenticated,service_role;
grant execute on function private.withdraw_cheque_evidence(uuid) to authenticated;
create function public.withdraw_cheque_evidence(p_evidence_id uuid) returns boolean
language sql security invoker set search_path='' as $$select private.withdraw_cheque_evidence(p_evidence_id);$$;
revoke all on function public.withdraw_cheque_evidence(uuid) from public,anon,authenticated,service_role;
grant execute on function public.withdraw_cheque_evidence(uuid) to authenticated;
