revoke insert,update,delete on public.approved_lease_templates from service_role;
create function private.guard_approved_lease_template() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Approved lease template versions are immutable' using errcode='23505';end if;
 if not exists(select 1 from public.staff_accounts s join auth.users u on u.id=s.user_id where s.user_id=new.approved_by and s.organization_id=new.organization_id and s.role='admin' and u.email_confirmed_at is not null) then raise exception 'Verified organization administrator approval required' using errcode='42501';end if;
 if new.template_key !~ '^[a-z][a-z0-9_-]{2,63}$' or length(trim(new.title)) not between 3 and 160 or length(trim(new.source_reference)) not between 5 and 500 then raise exception 'Bounded approved template metadata required' using errcode='22023';end if;
 return new;
end $$;
revoke all on function private.guard_approved_lease_template() from public,anon,authenticated,service_role;
create trigger guard_approved_lease_template before insert or update or delete on public.approved_lease_templates for each row execute function private.guard_approved_lease_template();
create or replace function private.register_approved_lease_template(p_request_id uuid,p_key text,p_expected_version integer,p_title text,p_source_reference text,p_sha256 text,p_business_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid;current_version integer;existing public.approved_lease_templates;created uuid;
begin
 select organization_id into org from public.staff_accounts where user_id=caller and role='admin';
 if org is null or org is distinct from private.verified_enquiry_staff_organization() then raise exception 'Verified administrator required' using errcode='42501';end if;
 if p_request_id is null or p_key is null or p_key !~ '^[a-z][a-z0-9_-]{2,63}$' or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_title is null or length(trim(p_title)) not between 3 and 160 or p_source_reference is null or length(trim(p_source_reference)) not between 5 and 500 or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$' or p_business_approved is distinct from true then raise exception 'Approved template reference and fingerprint required' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if org is distinct from private.verified_enquiry_staff_organization() or not exists(select 1 from public.staff_accounts where user_id=caller and organization_id=org and role='admin') then raise exception 'Administrator authority changed' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text||':'||p_key,117));
 select * into existing from public.approved_lease_templates where approved_by=caller and request_id=p_request_id;
 if existing.id is not null then
  if existing.organization_id<>org or existing.template_key<>p_key or existing.version<>p_expected_version+1 or existing.title<>trim(p_title) or existing.source_reference<>trim(p_source_reference) or existing.content_sha256<>p_sha256 then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',existing.id,'version',existing.version);
 end if;
 select coalesce(max(version),0) into current_version from public.approved_lease_templates where organization_id=org and template_key=p_key;
 if current_version<>p_expected_version then raise exception 'Template version changed; refresh' using errcode='40001';end if;
 insert into public.approved_lease_templates(organization_id,template_key,version,title,source_reference,content_sha256,approved_by,request_id) values(org,p_key,current_version+1,trim(p_title),trim(p_source_reference),p_sha256,caller,p_request_id) returning id into created;
 return jsonb_build_object('id',created,'version',current_version+1);
end $$;
