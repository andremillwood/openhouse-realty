create table public.property_security_assignments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),property_id uuid not null references public.properties(id),user_id uuid not null references auth.users(id),
 is_active boolean not null,version integer not null check(version>0),created_at timestamptz not null default now(),unique(property_id,user_id)
);
create index property_security_assignments_user_idx on public.property_security_assignments(user_id,property_id);
create index property_security_assignments_org_idx on public.property_security_assignments(organization_id,property_id,is_active,created_at desc,id);
alter table public.property_security_assignments enable row level security;
revoke all on public.property_security_assignments from public,anon,authenticated;
grant select on public.property_security_assignments to authenticated;
grant select,insert,update on public.property_security_assignments to service_role;
create policy "management read property security assignments" on public.property_security_assignments for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create policy "verified security reads own assignments" on public.property_security_assignments for select to authenticated using(user_id=(select private.verified_contractor_user()));
create table public.property_security_assignment_changes(
 id uuid primary key default gen_random_uuid(),assignment_id uuid not null references public.property_security_assignments(id),organization_id uuid not null references public.organizations(id),actor_user_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,
 previous_active boolean,new_active boolean not null,version integer not null,reason text not null,created_at timestamptz not null default now(),unique(actor_user_id,request_id)
);
create index property_security_assignment_changes_history_idx on public.property_security_assignment_changes(organization_id,assignment_id,created_at desc,id);
alter table public.property_security_assignment_changes enable row level security;
revoke all on public.property_security_assignment_changes from public,anon,authenticated;
grant select on public.property_security_assignment_changes to authenticated;
grant select,insert on public.property_security_assignment_changes to service_role;
create policy "management read security approval audit" on public.property_security_assignment_changes for select to authenticated using(organization_id=(select private.verified_work_order_organization()));
create function private.guard_property_security_binding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and row(new.organization_id,new.property_id,new.user_id) is distinct from row(old.organization_id,old.property_id,old.user_id) then raise exception 'Security account and property binding are immutable' using errcode='23505';end if;
 if not exists(select 1 from public.properties where id=new.property_id and organization_id=new.organization_id) then raise exception 'Organization property required' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_property_security_binding() from public,anon,authenticated;
create trigger guard_property_security_binding before insert or update on public.property_security_assignments for each row execute function private.guard_property_security_binding();
create function private.guard_security_property_organization() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.organization_id is distinct from old.organization_id and exists(select 1 from public.property_security_assignments where property_id=old.id) then raise exception 'Security assignment history fixes property organization' using errcode='23505';end if;return new;
end $$;
revoke all on function private.guard_security_property_organization() from public,anon,authenticated;
create trigger guard_security_property_organization before update of organization_id on public.properties for each row execute function private.guard_security_property_organization();
create function private.author_property_security_assignment(p_request_id uuid,p_assignment_id uuid,p_expected_version integer,p_property_id uuid,p_email text,p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();org uuid:=private.verified_work_order_organization();existing public.property_security_assignments;event public.property_security_assignment_changes;payload jsonb;created uuid;target uuid;confirmed timestamptz;matches integer;
begin
 if caller is null or org is null then raise exception 'Verified organization manager required' using errcode='42501';end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<0 or p_expected_version>=2147483647 or p_is_active is null or p_reason is null or length(trim(p_reason)) not between 5 and 500 or p_approved is distinct from true then raise exception 'Approved assignment and reason required' using errcode='22023';end if;
 payload:=jsonb_build_object('assignment_id',p_assignment_id,'version',p_expected_version,'property_id',p_property_id,'email',lower(trim(p_email)),'is_active',p_is_active,'reason',trim(p_reason));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(org::text,119));
 if private.verified_work_order_organization() is distinct from org then raise exception 'Manager authority changed' using errcode='42501';end if;
 select * into event from public.property_security_assignment_changes where actor_user_id=caller and request_id=p_request_id;
 if event.id is not null then if event.organization_id<>org or event.payload<>payload then raise exception 'Request ID already used' using errcode='22023';end if;return jsonb_build_object('id',event.assignment_id,'version',event.version);end if;
 if p_assignment_id is null then
 if p_expected_version<>0 or p_is_active is distinct from true or p_property_id is null or p_email is null or length(trim(p_email))>254 or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Property and verified account email required' using errcode='22023';end if;
 perform 1 from public.properties where id=p_property_id and organization_id=org for share;if not found then raise exception 'Organization property required' using errcode='42501';end if;
 select count(*) into matches from auth.users where lower(email)=lower(trim(p_email));if matches<>1 then raise exception 'Approved verified account required' using errcode='42501';end if;
 select id,email_confirmed_at into target,confirmed from auth.users where lower(email)=lower(trim(p_email)) for share;if target is null or confirmed is null then raise exception 'Approved verified account required' using errcode='42501';end if;
 insert into public.property_security_assignments(organization_id,property_id,user_id,is_active,version) values(org,p_property_id,target,true,1) returning id into created;
 else
 if p_property_id is not null or p_email is not null then raise exception 'Existing property and security identity cannot change' using errcode='22023';end if;
 select * into existing from public.property_security_assignments where id=p_assignment_id and organization_id=org for update;if existing.id is null then raise exception 'Organization assignment required' using errcode='42501';end if;
 if existing.version<>p_expected_version then raise exception 'Assignment changed' using errcode='40001';end if;
 if p_is_active then perform 1 from auth.users where id=existing.user_id and email_confirmed_at is not null for share;if not found then raise exception 'Verified security account required' using errcode='42501';end if;end if;
 update public.property_security_assignments set is_active=p_is_active,version=version+1 where id=existing.id returning id into created;
 end if;
 insert into public.property_security_assignment_changes(assignment_id,organization_id,actor_user_id,request_id,payload,previous_active,new_active,version,reason) values(created,org,caller,p_request_id,payload,existing.is_active,p_is_active,p_expected_version+1,trim(p_reason));
 return jsonb_build_object('id',created,'version',p_expected_version+1);
end $$;
revoke all on function private.author_property_security_assignment(uuid,uuid,integer,uuid,text,boolean,text,boolean) from public,anon,authenticated;
grant execute on function private.author_property_security_assignment(uuid,uuid,integer,uuid,text,boolean,text,boolean) to authenticated;
create function public.author_property_security_assignment(p_request_id uuid,p_assignment_id uuid,p_expected_version integer,p_property_id uuid,p_email text,p_is_active boolean,p_reason text,p_approved boolean) returns jsonb language sql security invoker set search_path='' as $$select private.author_property_security_assignment(p_request_id,p_assignment_id,p_expected_version,p_property_id,p_email,p_is_active,p_reason,p_approved);$$;
revoke all on function public.author_property_security_assignment(uuid,uuid,integer,uuid,text,boolean,text,boolean) from public,anon,authenticated;
grant execute on function public.author_property_security_assignment(uuid,uuid,integer,uuid,text,boolean,text,boolean) to authenticated;
