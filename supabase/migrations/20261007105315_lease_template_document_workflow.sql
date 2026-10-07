create function private.lease_document_admin(p_actor uuid,p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=p_actor and s.organization_id=p_org and s.role='admin' and u.email_confirmed_at is not null);
$$;
revoke all on function private.lease_document_admin(uuid,uuid) from public,anon,authenticated,service_role;
create function private.reserve_lease_template_document(p_template_id uuid,p_request_id uuid,p_file_name text,p_size bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();template public.approved_lease_templates;doc public.lease_template_documents;created uuid:=gen_random_uuid();path text;
begin
 if caller is null or org is null or not private.lease_document_admin(caller,org) then raise exception 'Verified administrator required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if not private.lease_document_admin(caller,org) then raise exception 'Administrator authority changed' using errcode='42501';end if;
 select * into template from public.approved_lease_templates where id=p_template_id and organization_id=org;
 if template.id is null then raise exception 'Approved organization template required' using errcode='42501';end if;
 if p_request_id is null or p_file_name is null or length(trim(p_file_name)) not between 1 and 160 or p_file_name ~ '[[:cntrl:]]' or position('/' in p_file_name)>0 or position(chr(92) in p_file_name)>0 or p_size is null or p_size not between 1 and 8388608 then raise exception 'Bounded PDF metadata required' using errcode='22023';end if;
 select * into doc from public.lease_template_documents where user_id=caller and request_id=p_request_id;
 if doc.id is not null then
  if doc.template_id<>template.id or doc.organization_id<>org or doc.file_name<>trim(p_file_name) or doc.declared_size<>p_size then raise exception 'Request ID already used' using errcode='22023';end if;
  if doc.state not in('reserved','certified') or doc.state='reserved' and doc.expires_at<=statement_timestamp() then raise exception 'Start a new reservation' using errcode='23505';end if;
  return jsonb_build_object('id',doc.id,'path',doc.object_path,'state',doc.state);
 end if;
 if exists(select 1 from public.lease_template_documents where template_id=template.id and (state='certified' or state='reserved' and expires_at>statement_timestamp())) then raise exception 'Template already has a document or active upload' using errcode='23505';end if;
 if (select count(*) from public.lease_template_documents where user_id=caller and created_at>statement_timestamp()-interval '1 day')>=50 then raise exception 'Daily legal upload limit reached' using errcode='23505';end if;
 path:=template.id::text||'/'||created::text||'.pdf';
 insert into public.lease_template_documents(id,template_id,organization_id,user_id,request_id,file_name,declared_size,object_path,expected_sha256) values(created,template.id,org,caller,p_request_id,trim(p_file_name),p_size,path,template.content_sha256);
 insert into public.lease_template_document_events(document_id,actor_user_id,event_name) values(created,caller,'reserved');
 return jsonb_build_object('id',created,'path',path,'state','reserved');
end $$;
create function private.finish_lease_template_document(p_actor uuid,p_document_id uuid,p_size bigint,p_sha256 text) returns boolean language plpgsql security definer set search_path='' as $$
declare doc public.lease_template_documents;
begin
 select * into doc from public.lease_template_documents where id=p_document_id;
 if doc.id is null or doc.user_id is distinct from p_actor then raise exception 'Own legal document required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(doc.organization_id::text,119));
 select * into doc from public.lease_template_documents where id=p_document_id for update;
 if not private.lease_document_admin(p_actor,doc.organization_id) then raise exception 'Verified administrator required' using errcode='42501';end if;
 if p_size is distinct from doc.declared_size or p_sha256 is distinct from doc.expected_sha256 then raise exception 'Actual PDF must match approved template fingerprint and size' using errcode='22023';end if;
 if doc.state='certified' then return true;end if;
 if doc.state<>'reserved' or doc.expires_at<=statement_timestamp() then raise exception 'Legal reservation unavailable' using errcode='23505';end if;
 if exists(select 1 from public.lease_template_documents where template_id=doc.template_id and state='certified') then raise exception 'Template already certified' using errcode='23505';end if;
 if not exists(select 1 from storage.objects where bucket_id='lease-template-documents' and name=doc.object_path) then raise exception 'Uploaded legal PDF required' using errcode='23505';end if;
 update public.lease_template_documents set state='certified',sha256=p_sha256,actual_size=p_size,certified_at=statement_timestamp() where id=doc.id;
 insert into public.lease_template_document_events(document_id,actor_user_id,event_name) values(doc.id,p_actor,'certified');return true;
end $$;
create function private.withdraw_lease_template_document(p_document_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();doc public.lease_template_documents;
begin
 if caller is null or org is null or not private.lease_document_admin(caller,org) then raise exception 'Verified administrator required' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if not private.lease_document_admin(caller,org) then raise exception 'Administrator authority changed' using errcode='42501';end if;
 select * into doc from public.lease_template_documents where id=p_document_id and organization_id=org and user_id=caller for update;
 if doc.id is null then raise exception 'Own legal reservation required' using errcode='42501';end if;
 if doc.state='withdrawn' then return true;end if;
 if doc.state<>'reserved' then raise exception 'Certified or terminal legal document cannot be withdrawn' using errcode='23505';end if;
 update public.lease_template_documents set state='withdrawn',withdrawn_at=statement_timestamp() where id=doc.id;
 insert into public.lease_template_document_events(document_id,actor_user_id,event_name) values(doc.id,caller,'withdrawn');return true;
end $$;
create function private.lease_template_document_storage_access(p_path text,p_operation text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_enquiry_staff_organization();doc public.lease_template_documents;
begin
 if caller is null or org is null then return false;end if;
 select * into doc from public.lease_template_documents where object_path=p_path and organization_id=org;
 if doc.id is null then return false;end if;
 if p_operation='read' and doc.state='certified' then return true;end if;
 return p_operation in('read','insert') and doc.user_id=caller and doc.state='reserved' and doc.expires_at>statement_timestamp() and private.lease_document_admin(caller,org);
end $$;
revoke all on function private.lease_template_document_storage_access(text,text) from public,anon,authenticated,service_role;
grant execute on function private.lease_template_document_storage_access(text,text) to authenticated;
create policy "own legal PDF reservation insert" on storage.objects for insert to authenticated with check(bucket_id='lease-template-documents' and private.lease_template_document_storage_access(name,'insert'));
create policy "authorized legal PDF read" on storage.objects for select to authenticated using(bucket_id='lease-template-documents' and private.lease_template_document_storage_access(name,'read'));

revoke all on function private.reserve_lease_template_document(uuid,uuid,text,bigint) from public,anon,authenticated,service_role;
grant execute on function private.reserve_lease_template_document(uuid,uuid,text,bigint) to authenticated;
create function public.reserve_lease_template_document(p_template_id uuid,p_request_id uuid,p_file_name text,p_size bigint) returns jsonb language sql security invoker set search_path='' as $$select private.reserve_lease_template_document(p_template_id,p_request_id,p_file_name,p_size);$$;
revoke all on function public.reserve_lease_template_document(uuid,uuid,text,bigint) from public,anon,authenticated,service_role;
grant execute on function public.reserve_lease_template_document(uuid,uuid,text,bigint) to authenticated;

revoke all on function private.finish_lease_template_document(uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function private.finish_lease_template_document(uuid,uuid,bigint,text) to service_role;
create function public.finish_lease_template_document(p_actor uuid,p_document_id uuid,p_size bigint,p_sha256 text) returns boolean language sql security invoker set search_path='' as $$select private.finish_lease_template_document(p_actor,p_document_id,p_size,p_sha256);$$;
revoke all on function public.finish_lease_template_document(uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_lease_template_document(uuid,uuid,bigint,text) to service_role;

revoke all on function private.withdraw_lease_template_document(uuid) from public,anon,authenticated,service_role;
grant execute on function private.withdraw_lease_template_document(uuid) to authenticated;
create function public.withdraw_lease_template_document(p_document_id uuid) returns boolean language sql security invoker set search_path='' as $$select private.withdraw_lease_template_document(p_document_id);$$;
revoke all on function public.withdraw_lease_template_document(uuid) from public,anon,authenticated,service_role;
grant execute on function public.withdraw_lease_template_document(uuid) to authenticated;
