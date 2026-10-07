-- Access approval is not proof of legal title or an ownership percentage.
create table public.owner_property_access(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 property_id uuid not null references public.properties(id),
 user_id uuid not null references auth.users(id),
 is_active boolean not null,
 version integer not null check(version>0),
 created_at timestamptz not null default now(),
 unique(property_id,user_id)
);
create index owner_property_access_user_idx on public.owner_property_access(user_id,is_active,property_id);
create index owner_property_access_org_idx on public.owner_property_access(organization_id,property_id,created_at desc,id);
alter table public.owner_property_access enable row level security;
revoke all on public.owner_property_access from public,anon,authenticated,service_role;
grant select on public.owner_property_access to authenticated;
create function private.verified_owner_user() returns uuid language sql stable security definer set search_path='' as $$
 select id from auth.users where id=auth.uid() and email_confirmed_at is not null;
$$;
revoke all on function private.verified_owner_user() from public,anon,authenticated,service_role;
grant execute on function private.verified_owner_user() to authenticated;
create policy "administrators read owner access register" on public.owner_property_access for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create policy "verified owners read own access register" on public.owner_property_access for select to authenticated using(user_id=(select private.verified_owner_user()));
create table public.owner_property_access_changes(
 id uuid primary key default gen_random_uuid(),access_id uuid not null references public.owner_property_access(id),
 organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),
 request_id uuid not null,payload jsonb not null,before_record jsonb,after_record jsonb not null,
 version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index owner_property_access_changes_history_idx on public.owner_property_access_changes(organization_id,access_id,created_at desc,id);
alter table public.owner_property_access_changes enable row level security;
revoke all on public.owner_property_access_changes from public,anon,authenticated,service_role;
grant select on public.owner_property_access_changes to authenticated;
create policy "administrators read owner access approval audit" on public.owner_property_access_changes for select to authenticated using(organization_id=(select private.verified_staff_admin_organization()));
create function private.guard_owner_property_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='owner_property_access' then
  if row(new.organization_id,new.property_id,new.user_id,new.created_at) is distinct from row(old.organization_id,old.property_id,old.user_id,old.created_at) then raise exception 'Owner access identity and property are immutable' using errcode='23505';end if;
 else
  if new.organization_id is distinct from old.organization_id and exists(select 1 from public.owner_property_access where property_id=old.id) then raise exception 'Property has owner access history' using errcode='23505';end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_owner_property_binding() from public,anon,authenticated,service_role;
create trigger guard_owner_property_binding before update on public.owner_property_access for each row execute function private.guard_owner_property_binding();
create trigger guard_owner_property_binding before update of organization_id on public.properties for each row execute function private.guard_owner_property_binding();
create function private.keep_owner_access_audit() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Owner access approval history is immutable' using errcode='23505';end $$;
revoke all on function private.keep_owner_access_audit() from public,anon,authenticated,service_role;
create trigger keep_owner_access_audit before update or delete on public.owner_property_access_changes for each row execute function private.keep_owner_access_audit();
create function private.author_owner_property_access(p_request_id uuid,p_access_id uuid,p_expected_version integer,p_property_id uuid,p_email text,p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_staff_admin_organization();target uuid;matches integer;
 existing public.owner_property_access;event public.owner_property_access_changes;payload jsonb;created uuid;
begin
 if caller is null or org is null then raise exception 'Verified organization administrator required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_is_active is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Access approval, revision and reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('access_id',p_access_id,'version',p_expected_version,'property_id',p_property_id,'email',lower(trim(p_email)),'is_active',p_is_active,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_staff_admin_organization() is distinct from org then raise exception 'Administrator authority changed' using errcode='42501';end if;
 select * into event from public.owner_property_access_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then
  if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
  return jsonb_build_object('id',event.access_id,'version',event.version);
 end if;
 if p_access_id is null then
  if p_expected_version<>0 or p_is_active is distinct from true or p_property_id is null or p_email is null or length(trim(p_email))>254 or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'New access needs approved property and verified email' using errcode='22023';end if;
  perform 1 from public.properties where id=p_property_id and organization_id=org for share;
  if not found then raise exception 'Organization property required' using errcode='42501';end if;
  select count(*) into matches from auth.users where lower(email)=lower(trim(p_email));
  if matches<>1 then raise exception 'Approved verified account required' using errcode='42501';end if;
  select id into target from auth.users where lower(email)=lower(trim(p_email)) and email_confirmed_at is not null for share;
  if target is null then raise exception 'Approved verified account required' using errcode='42501';end if;
  insert into public.owner_property_access(organization_id,property_id,user_id,is_active,version) values(org,p_property_id,target,true,1) returning id into created;
 else
  if p_email is not null or p_property_id is not null then raise exception 'Existing access identity cannot be changed' using errcode='22023';end if;
  select * into existing from public.owner_property_access where id=p_access_id and organization_id=org for update;
  if existing.id is null then raise exception 'Organization access record required' using errcode='42501';end if;
  if existing.version<>p_expected_version then raise exception 'Access changed; refresh' using errcode='40001';end if;
  if p_is_active then
   perform 1 from auth.users where id=existing.user_id and email_confirmed_at is not null for share;
   if not found then raise exception 'Verified account required for active access' using errcode='42501';end if;
  end if;
  update public.owner_property_access set is_active=p_is_active,version=version+1 where id=existing.id returning id into created;
 end if;
 insert into public.owner_property_access_changes(access_id,organization_id,actor_user_id,request_id,payload,before_record,after_record,version,reason)
 values(created,org,caller,p_request_id,payload,case when existing.id is not null then jsonb_build_object('is_active',existing.is_active) else null end,jsonb_build_object('is_active',p_is_active),p_expected_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_version+1);
end $$;
revoke all on function private.author_owner_property_access(uuid,uuid,integer,uuid,text,boolean,text,boolean) from public,anon,authenticated,service_role;
grant execute on function private.author_owner_property_access(uuid,uuid,integer,uuid,text,boolean,text,boolean) to authenticated;
create function public.author_owner_property_access(p_request_id uuid,p_access_id uuid,p_expected_version integer,p_property_id uuid,p_email text,p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$
 select private.author_owner_property_access(p_request_id,p_access_id,p_expected_version,p_property_id,p_email,p_is_active,p_reason,p_approved);
$$;
revoke all on function public.author_owner_property_access(uuid,uuid,integer,uuid,text,boolean,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.author_owner_property_access(uuid,uuid,integer,uuid,text,boolean,text,boolean) to authenticated;
